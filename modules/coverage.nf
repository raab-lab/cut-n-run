// Compute coverage

process coverage {
	module 'deeptools/3.2.0'
	label 'medium'
	tag "${meta.id}"
	publishDir "${params.outdir}/${meta.id}/aligned"

	input:
	tuple val(meta), path(bam), path(bai)
	val norm_factor

	output:
	tuple val(meta),  path("*.coverage.bw")

	script:
	"""
	bamCoverage -b $bam \\
		-o ${meta.id}.coverage.bw \\
		--binSize 30 \\
		--smoothLength 60 \\
		--numberOfProcessors $task.cpus \\
		--scaleFactor $norm_factor \\
		--normalizeUsing RPKM \\
		--extendReads \\
		--ignoreDuplicates \\
		--effectiveGenomeSize 2308125349 \\
	"""
}
