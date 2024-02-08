// Compute coverage normalization factors
// TODO: Parse the params column and pass it here
process normalize {
	tag "$meta.group_norm"
	module 'r/4.1.0'
	cache 'lenient'

	memory { 8.GB * task.attempt }
	errorStrategy { task.exitStatus == 137 ? 'retry' : 'finish' }
	maxRetries 3

	publishDir "${params.outdir}/norm_factors/", mode: 'copy'

	input:
	tuple val(group), val(meta), path(bams), path(index)

	output:
	val(meta), emit: meta
	path "${group}_norm_factors.csv", emit: norm_factors

	script:
	"""
	normfactors_csaw.R ${meta.norm_params[0]} ${group}_norm_factors.csv $bams
	"""
}
