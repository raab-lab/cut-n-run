// Average wiggle tracks

process average {
	tag "Group $group_avg"
	publishDir "${params.outdir}/bw", mode: 'copy'

	conda 'bioconda::wiggletools'
	module 'ucsctools/320'

	cpus 4
	memory '16G'
	time '2h'

	input:
	tuple val(meta), path(bws), val(group_avg)
	path(chrom_sizes)

	output:
	path("*mean.bw")

	script:
	"""
	wiggletools mean ${bws} |\\
		awk '\$1 ~ /^chr[XY0-9]+\$/' |\\
		wigToBigWig stdin ${chrom_sizes} group${group_avg}_mean.bw
	"""
}
