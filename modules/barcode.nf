// Barcoded spike-in nucleosome calibration.
//
// Designer-nucleosome panels share a Widom 601 backbone and differ only in a
// short barcode, so competitive alignment gives them MAPQ 0-1 and a MAPQ
// filter would discard the calibration signal. They are counted by exact
// sequence match instead, which is what the vendor protocols specify.

process count_barcodes {
	label 'medium'
	tag "${meta.id}"
	publishDir "${params.outdir}/manifests/barcodes", mode: "copy", pattern: "*.tsv"

	input:
	tuple val(meta), path(r1), path(r2)
	path barcode_fasta

	output:
	tuple val(meta), path("${meta.id}.barcode_counts.tsv"), emit: counts
	path "${meta.id}.barcode_summary.tsv", emit: summary

	script:
	// Counted on the merged, untrimmed reads: trimming can clip a barcode that
	// sits near a read end and silently reduce the calibration count.
	"""
	count_barcodes.py \\
		--sample-id "${meta.id}" \\
		--barcodes ${barcode_fasta} \\
		--r1 ${r1} --r2 ${r2} \\
		--counts ${meta.id}.barcode_counts.tsv \\
		--summary ${meta.id}.barcode_summary.tsv
	"""
}

process host_pair_counts {
	label 'medium'
	tag "${meta.id}"
	module 'samtools/1.22'

	input:
	tuple val(meta), path(bam), path(bai)
	val mapq

	output:
	tuple val(meta), path("${meta.id}.host_counts.tsv"), emit: counts

	script:
	// The same classifier as the competitive path, with a prefix that cannot
	// occur, so every pair falls in both_host and the counting semantics
	// (pair-level, both mates over the threshold) stay identical.
	"""
	samtools collate -u -O ${bam} | \\
		samtools view -h - | \\
		classify_calibration_pairs.py \\
			--sample-id "${meta.id}" \\
			--mapq "${mapq}" \\
			--calib-prefix '__no_calibrator_contig__' \\
			--host-sam /dev/null \\
			--counts ${meta.id}.host_counts.tsv \\
			--summary ${meta.id}.host_summary.tsv
	"""
}

process barcode_calibration_summary {
	label 'single'
	tag "${meta.id}"
	publishDir "${params.outdir}/manifests/calibration", mode: "copy"

	input:
	tuple val(meta), path(barcode_counts), path(host_counts)
	path barcode_fasta

	output:
	path "${meta.id}.calibration_summary.tsv", emit: summary

	script:
	// The antibody names the on-target panel member; off-target members
	// measure cross-reactivity and must not enter the size factor.
	"""
	build_barcode_calibration_summary.py \\
		--sample-id "${meta.id}" \\
		--barcode-counts ${barcode_counts} \\
		--barcodes ${barcode_fasta} \\
		--target "${meta.ab}" \\
		--host-counts ${host_counts} \\
		--summary ${meta.id}.calibration_summary.tsv
	"""
}
