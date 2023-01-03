// Call peaks with macs2

// call peaks
process macs {
	label 'medium'
	tag "$meta.id"
	publishDir "${params.outdir}/peaks/", mode: "copy"
	publishDir "${params.outdir}/${meta.id}/peaks"
	module 'macs/2.2.7.1'

	input:
	tuple val(meta), path(bam), path(bai)
	val genomeSize

	output:
	tuple val(meta), path("*.narrowPeak"), emit: peaks
	path "*_peaks.xls", emit: stats

	script:
	"""
	macs2 callpeak -t ${bam} -n ${meta.id} -f BAMPE -g $genomeSize --call-summits -q 0.01
	"""
}
