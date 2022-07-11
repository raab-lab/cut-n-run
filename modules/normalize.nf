// Compute coverage normalization factors

process normalize {
	tag "$meta.ab"
	module 'r/4.1.0'
	cache 'lenient'
	publishDir "${params.outdir}/norm_factors/", mode: 'copy'

	input:
	tuple val(ab), val(meta), path(bams), path(index)

	output:
	path "${ab}_norm_factors.csv"

	script:
	"""
	normfactors_csaw.R --${params.norm_method} ${ab}_norm_factors.csv $bams
	"""
}
