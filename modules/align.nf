// Alignment

process bt2 {
	tag "$meta.id"
	cpus 8
	memory '8GB'
	time '24h'
	publishDir "${params.outdir}/bams", mode: "copy"
	publishDir "${params.outdir}/${meta.id}/aligned/"

	module 'bowtie2/2.3.4.1'
	module 'samtools/1.20'

	input:
	tuple val(meta), path(fq1), path(fq2)
	path index

	output:
	tuple val(meta), path("*aligned.bam"), emit: bam
	path "*.alignment_stats.txt", emit: stats

	script:

	"""
	bowtie2 \\
		-x ${index}/genome \\
		-p ${task.cpus} \\
		--very-sensitive-local \\
		-X 800 \\
		-1 $fq1 \\
		-2 $fq2 \\
		2>${meta.id}.alignment_stats.txt |\\
		samtools view -b > ${meta.id}.aligned.bam
	"""
}
