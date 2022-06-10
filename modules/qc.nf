// QC processes

// Trim adaptors and run fastqc

process trim {
   tag "${meta.id}"
   label 'trim'
   module 'trim_galore/0.6.2'
   module 'fastqc'

   publishDir "${params.outdir}/${meta.id}/qc"

   input:
   tuple val(meta), path(fastq1), path(fastq2)

   output:
   tuple val(meta), path("*_val_1.fq.gz"), path("*_val_2.fq.gz"), emit: trimmed
   path "*.{zip,html}",	emit: fqc

   script:
   """
   trim_galore -j ${task.cpus} --fastqc --paired --gzip ${fastq1} ${fastq2}
   """
}

// Insert sizes

process picard_cis {
	label 'medium'
	publishDir "${params.outdir}/${meta.id}/qc"
	module 'picard/2.20.0'

	input:
	tuple val(meta), path(bam), path(bai)

	output:
	path "*metrics*", emit: metrics

	"""
	picard CollectInsertSizeMetrics \\
		I=${bam} \\
		O=${meta.id}_metrics.txt \\
		H=${meta.id}_histogram.pdf
	"""
}
