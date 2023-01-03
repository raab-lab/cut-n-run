// Create the samplesheet given a data directory
include { create_ss }		from '../modules/create_samplesheet'

workflow CREATE_SAMPLESHEET {

	take:
	inventory

	main:

	create_ss(inventory)

	emit:
	create_ss.out

}

