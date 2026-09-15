process multiqc {
	module 'multiqc/1.28'
	cpus 2
	memory '16G'
	publishDir "${params.outdir}", mode: 'copy'

	input:
	path fastqc
	path bt2_log
	path macs_stats
	path ins_metrics
	// In calibration mode these are combined-reference duplicate metrics: they
	// summarize host plus calibrator reads and must not be read as host-only.
	// Species-specific duplicate fractions come from the classifier tables.
	path combined_dup_metrics

	output:
	path "multiqc_report.html"
	path "multiqc_data"

	"""
	multiqc .	
	"""
}
