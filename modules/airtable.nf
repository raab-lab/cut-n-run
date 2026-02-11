// Nextflow processes to interface with Airtable

process pull_experiment {

	tag "AT Experiment"
	executor 'local'
	module 'python/3.12.4'

	input:
	val exp_id

	output:
	stdout

	script:
	"""
	pull_experiment.py 'CUT&RUN' $exp_id	
	"""
}

process update_paths {

	tag "Update"
	executor 'local'
	module 'python/3.12.4'

	input:
	path samplesheet

	script:
	"""
	update_samples.py $samplesheet
	"""
}

process pull_samples {

	tag "AT Samples"
	module 'python/3.12.4'

	input:
	val exp_id

	output:
	path ("samplesheet.csv")

	script:
	"""
	pull_samples.py  'CUT&RUN' $exp_id
	"""
}
