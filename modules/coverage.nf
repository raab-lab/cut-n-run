// Compute coverage

process coverage {
	module 'deeptools/3.2.0'
	label 'medium'
	tag "${meta.id}"
	publishDir "${params.outdir}/bw", mode: "copy"

	input:
	tuple val(meta), path(bam), path(bai)
	val workflow

	output:
	tuple val(meta),  path("*.coverage.bw")

	script:

	def norm_method = ''
	if (workflow == 1){
		norm_method = "--normalizeUsing RPKM"
		norm_flag = "rpkm"
	} else {
		norm_method = "--scaleFactor ${meta.norm_factor}"
		norm_flag = "scaled"
	}

	"""
	bamCoverage -b $bam \\
		-o ${meta.id}_${norm_flag}.coverage.bw \\
		--binSize 30 \\
		--smoothLength 60 \\
		--numberOfProcessors $task.cpus \\
		$norm_method \\
		--extendReads \\
		--ignoreDuplicates \\
		--effectiveGenomeSize 2308125349 \\
	"""
}
