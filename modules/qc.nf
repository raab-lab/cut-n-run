// QC processes

// Trim adaptors and run fastqc

process trim {
   tag "${meta.id}"
   label 'trim'
   module 'trim_galore/0.6.7'
   module 'fastqc'

   publishDir "${params.outdir}/${meta.id}/qc"

   input:
   tuple val(meta), path(fastq1), path(fastq2)

   output:
   tuple val(meta), path("*_val_1.fq.gz"), path("*_val_2.fq.gz", optional: true), emit: trimmed
   path "*.{zip,html}",	emit: fqc

   script:

   def reads = params.single ? "$fastq1" : "--paired $fastq1 $fastq2"   
   """
   trim_galore -j ${task.cpus} --fastqc --gzip --basename ${meta.id} $reads
   """
}

// Insert sizes

process picard_cis {
	tag "${meta.id}"
	label 'medium'
	module 'picard/2.26.11'
	module 'r/4.4.0'

	publishDir "${params.outdir}/${meta.id}/qc"

	input:
	tuple val(meta), path(bam), path(bai)

	output:
	path "*metrics*", emit: metrics

	script:
	"""
	picard CollectInsertSizeMetrics \\
		I=${bam} \\
		O=${meta.id}_metrics.txt \\
		H=${meta.id}_histogram.pdf
	"""
}

// Remove duplicates

process picard_md {
	tag "$meta.id"
	label "large"
	module 'picard/2.26.11'
	module 'r/4.4.0'

	publishDir "${params.outdir}/${meta.id}/qc"

	input:
	tuple val(meta), path(bam), path(bai)

	output:
	tuple val(meta), path("*sorted_markdup.bam"), path("*.bai"), emit: bam
	path "*metrics.txt", emit: metrics

	script:
	"""
	picard MarkDuplicates \\
		I=$bam \\
		O=${meta.id}_sorted_markdup.bam \\
		M=${meta.id}_dup_metrics.txt \\
		CREATE_INDEX=true
	"""
}
