// Merge, sort, and index with samtools

process sort {
      label 'medium'
      tag "${meta.id}"
      publishDir "${params.outdir}/${meta.id}/aligned/"
      module 'samtools/1.9'

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

