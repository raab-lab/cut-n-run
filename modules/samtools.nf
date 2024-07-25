// Merge, sort, and index with samtools

process sort {
      label 'medium'
      tag "${meta.id}"
      publishDir "${params.outdir}/bams/sorted", mode: "copy"
      publishDir "${params.outdir}/${meta.id}/aligned/"
      module 'samtools/1.16'

      input:
      tuple val(meta), path(bam)

      output:
      tuple val(meta), path("*.aligned.sorted.bam"), path("*.aligned.sorted.bam.bai") 

      script:

      """
      samtools sort -@ ${task.cpus} ${bam} > ${meta.id}.aligned.sorted.bam
      samtools index ${meta.id}.aligned.sorted.bam
      """
   }

process filter {
	tag "${meta.id}"
	publishDir "${params.outdir}/bams/filtered", mode: "copy"
	publishDir "${params.outdir}/${meta.id}/aligned/"
	module 'bedtools/2.30'
	module 'samtools/1.16'

	when:
	!params.skip_filter

	input:
	tuple val(meta), path(bam), path(bai)
	val mapq
	val mode

	output:
	tuple val(meta), path("*filtered.sorted.bam"), path("*filtered.sorted.bam.bai")

	script:

	def mitoFilter = mode == 'atac' ? "-e 'rname != \"chrM\"'" : ""
	def exclusion = mode == 'atac' ? "| bedtools intersect -v -a stdin -b ${params.exclusionList}" : ""

	"""
	samtools view -b -q ${mapq} ${mitoFilter} ${bam} ${exclusion} > ${meta.id}_mapq${mapq}_filtered.sorted.bam

	samtools index ${meta.id}_mapq${mapq}_filtered.sorted.bam
	"""
}
