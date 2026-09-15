// SRA acquisition and manifest validation

process check_sra_manifest {
	label 'single'
	module 'r/4.4.0'
	tag "SRA manifest"

	input:
	path manifest

	output:
	path 'sra_manifest_checked.csv', emit: manifest

	script:
	"""
	check_sra_manifest.R ${manifest}
	"""
}
