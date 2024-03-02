// Compute coverage normalization factors

process normalize {
	tag "$meta.group_norm"
	module 'r/4.1.0'
	cache 'lenient'
	publishDir "${params.outdir}/norm_factors/", mode: 'copy'

	input:
	tuple val(group), val(meta), path(bams), path(index)

	output:
	val(meta), emit: meta
	path "${group}_norm_factors.csv", emit: norm_factors

	script:
	"""
	normfactors_csaw.R --${params.norm_method} ${group}_norm_factors.csv $bams
	"""
}
