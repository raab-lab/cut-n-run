// Compute coverage

process coverage {
	module 'deeptools/3.2.0'
	tag "${meta.id}"
	cpus 16
	memory { 24.GB * task.attempt }
	time { 24.h * task.attempt }

	publishDir "${params.outdir}/bw", mode: "copy"
	publishDir "${params.outdir}/${meta.id}/bw"

	input:
	tuple val(meta), path(bam), path(bai)
	val workflow
	val genomeSize

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
		--effectiveGenomeSize $genomeSize \\
	"""
}
