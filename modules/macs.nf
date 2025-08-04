// Call peaks with macs2

// call peaks
process macs {
	label 'medium'
	tag "$meta.id"
	publishDir "${params.outdir}/peaks/", mode: "copy"
	publishDir "${params.outdir}/${meta.id}/peaks"
//	module 'macs/2.2.9.1'

	input:
	tuple val(meta), path(bam), path(bai)
	val genomeSize

	output:
	tuple val(meta), path("*Peak"), emit: peaks
	path "*_peaks.xls", emit: stats

	script:

	def peakSize = params.broad ? "--broad --broad-cutoff $params.broad" : "--call-summits -q ${params.macs_qvalue}"

	"""
	module load macs/2.2.9.1
	macs2 callpeak -t ${bam} -n ${meta.id} -f BAMPE -g $genomeSize $peakSize
	"""
}
