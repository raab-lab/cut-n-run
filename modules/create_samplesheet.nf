// Create samplesheet from directory

process create_ss {

	tag "samplesheet"
	publishDir "$params.outdir", mode: "copy"

	input:
	path inventory

	output:
	path "samplesheet.csv"

	script:
	"""
	bash dir_to_samplesheet.sh $inventory
	"""
}
