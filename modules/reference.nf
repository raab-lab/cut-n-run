// Combined host + external-calibrator reference construction.
//
// The index is content-addressed, so a shared cache entry is reused whenever
// both source FASTAs and the Bowtie2 index format are unchanged. Without
// --combined_index_cache the same validated build runs in the work directory.

process build_combined_reference {
	label 'big_mem'
	module 'bowtie2/2.5.4'
	tag "combined reference"
	publishDir "${params.outdir}/manifests", mode: "copy", pattern: "reference_manifest.json"

	input:
	path host_fasta
	path external_fasta
	val cache_dir

	output:
	path "combined_index", emit: index
	path "reference_manifest.json", emit: manifest

	script:
	def cache_arg = cache_dir ? "--cache-dir ${cache_dir}" : "--output-dir combined_index"
	"""
	set -euo pipefail

	resolved=\$(build_combined_reference.py \\
		--host ${host_fasta} \\
		--external ${external_fasta} \\
		--threads ${task.cpus} \\
		${cache_arg})

	# Stage the resolved entry under a stable name. A cached entry is linked
	# rather than copied; an uncached build already lives at this path.
	if [ "\$resolved" != "\$PWD/combined_index" ]; then
		ln -s "\$resolved" combined_index
	fi

	cp -L combined_index/reference_manifest.json reference_manifest.json
	"""
}

// One-row-per-sample mapping manifest.
//
// Provenance is attached here rather than inferred later: the cache key and
// FASTA hashes pin which reference the counts came from, and the argument
// string pins the alignment behaviour that proper-pair classification depends
// on.

process mapping_manifest {
	label 'single'
	tag "${meta.id}"
	module 'samtools/1.22'

	input:
	tuple val(meta), path(host_bam), path(host_bai), path(bt2_args)
	path reference_manifest
	val alignment_mode
	val pipeline_revision

	output:
	path "${meta.id}.mapping.tsv", emit: manifest

	script:
	"""
	set -euo pipefail

	bt2_args=\$(head -n 1 ${bt2_args})
	bt2_version=\$(sed -n '2p' ${bt2_args})
	samtools_version=\$(samtools --version | head -n 1)
	cache_key=\$(python3 -c "import json,sys; print(json.load(open('${reference_manifest}'))['cache_key'])")
	host_sha=\$(python3 -c "import json,sys; print(json.load(open('${reference_manifest}'))['host_sha256'])")
	external_sha=\$(python3 -c "import json,sys; print(json.load(open('${reference_manifest}'))['external_sha256'])")

	printf 'SampleID\\thost_bam\\thost_bai\\talignment_mode\\tbowtie2_args\\tbowtie2_version\\tsamtools_version\\treference_cache_key\\thost_fasta_sha256\\texternal_fasta_sha256\\tpipeline_revision\\n' > ${meta.id}.mapping.tsv
	printf '%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \\
		'${meta.id}' '${host_bam.name}' '${host_bai.name}' '${alignment_mode}' \\
		"\${bt2_args}" "\${bt2_version}" "\${samtools_version}" \\
		"\${cache_key}" "\${host_sha}" "\${external_sha}" \\
		'${pipeline_revision}' >> ${meta.id}.mapping.tsv
	"""
}
