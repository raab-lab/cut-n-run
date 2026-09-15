// SRA acquisition: manifest validation, download, conversion, and merging.
//
// Downloads are network-bound and carry the 'download' label so they land on a
// transfer partition; conversion and compression are CPU and scratch-I/O bound
// and carry the 'convert' label instead.

process check_sra_manifest {
	label 'single'
	module 'r/4.4.0'
	tag "SRA manifest"

	input:
	path manifest

	output:
	path 'sra_manifest_checked.csv', emit: manifest

	script:
	"""
	check_sra_manifest.R ${manifest}
	"""
}

process prefetch_sra {
	label 'download'
	module 'sratoolkit/3.2.1'
	tag "${run}"

	input:
	tuple val(meta), val(run)
	val max_size

	output:
	tuple val(meta), val(run), path("${run}"), emit: archive

	script:
	"""
	prefetch --max-size ${max_size} --output-directory . ${run}
	vdb-validate ${run}/${run}.sra
	"""
}

process convert_sra {
	label 'convert'
	module 'sratoolkit/3.2.1'
	module 'pigz/2.8'
	tag "${run}"

	input:
	tuple val(meta), val(run), path(archive)
	val max_size

	output:
	tuple val(meta), val(run), path("${run}_1.fastq.gz"), path("${run}_2.fastq.gz"), emit: reads
	path "${run}.acquisition.tsv", emit: acquisition

	script:
	"""
	set -euo pipefail

	# Refuse to start a conversion that cannot fit. SRA Toolkit guidance puts
	# peak conversion space at roughly 17x the accession size.
	archive_bytes=\$(du -sb ${archive} | cut -f1)
	estimate=\$(( archive_bytes * 17 ))
	avail=\$(df -Pk . | awk 'NR==2 {print \$4}')
	avail=\$(( avail * 1024 ))
	if (( avail < estimate )); then
		echo "insufficient scratch space for ${run}: need \${estimate} bytes, have \${avail}" >&2
		exit 1
	fi

	mkdir -p tmp
	fasterq-dump --split-files --threads ${task.cpus} --temp ./tmp --outdir . ${archive}
	rm -rf tmp

	# Authoritative paired-end check; also rejects an unmated third file.
	validate_sra_fastqs.sh ${run} . > ${run}.validation.tsv
	r1_records=\$(awk 'NR==2 {print \$2}' ${run}.validation.tsv)
	r2_records=\$(awk 'NR==2 {print \$3}' ${run}.validation.tsv)

	pigz -p ${task.cpus} ${run}_1.fastq ${run}_2.fastq
	pigz -t ${run}_1.fastq.gz
	pigz -t ${run}_2.fastq.gz

	r1_bytes=\$(stat -c %s ${run}_1.fastq.gz)
	r2_bytes=\$(stat -c %s ${run}_2.fastq.gz)
	r1_sha=\$(sha256sum ${run}_1.fastq.gz | cut -d' ' -f1)
	r2_sha=\$(sha256sum ${run}_2.fastq.gz | cut -d' ' -f1)
	toolkit=\$(fasterq-dump --version | tr -d '\\n' | sed 's/.*: *//')

	printf 'Run\\tSampleID\\tLibraryLayout\\tPlatform\\tR1_file\\tR2_file\\tR1_records\\tR2_records\\tR1_bytes\\tR2_bytes\\tR1_sha256\\tR2_sha256\\tarchive_bytes\\tconversion_estimate_bytes\\tsra_max_size\\tsra_toolkit_version\\tstatus\\n' > ${run}.acquisition.tsv
	printf '%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \\
		'${run}' '${meta.lib_id}' '${meta.layout}' '${meta.platform}' \\
		'${run}_1.fastq.gz' '${run}_2.fastq.gz' \\
		"\${r1_records}" "\${r2_records}" "\${r1_bytes}" "\${r2_bytes}" \\
		"\${r1_sha}" "\${r2_sha}" "\${archive_bytes}" "\${estimate}" \\
		'${max_size}' "\${toolkit}" 'complete' >> ${run}.acquisition.tsv
	"""
}

process merge_sra_runs {
	label 'convert'
	module 'pigz/2.8'
	tag "${meta.id}"

	input:
	tuple val(meta), val(runs), path(r1), path(r2)

	output:
	tuple val(meta), path("${meta.id}_R1.fastq.gz"), path("${meta.id}_R2.fastq.gz"), emit: reads

	script:
	// Concatenated gzip members are a valid gzip stream, so runs belonging to
	// one library merge without recompression. Single-run samples take the same
	// path so that downstream filenames are uniform.
	"""
	set -euo pipefail
	cat ${r1} > ${meta.id}_R1.fastq.gz
	cat ${r2} > ${meta.id}_R2.fastq.gz
	pigz -t ${meta.id}_R1.fastq.gz
	pigz -t ${meta.id}_R2.fastq.gz
	"""
}
