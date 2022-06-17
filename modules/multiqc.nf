process multiqc {
	module 'multiqc/1.11'
	cpus 2
	memory '16G'
	publishDir "${params.outdir}", mode: 'copy'

	input:
	path fastqc
	path bt2_log
	path macs_stats
	path ins_metrics
	path dup_metrics

	output:
	path "multiqc_report.html"
	path "multiqc_data"

	"""
	multiqc .	
	"""
}
