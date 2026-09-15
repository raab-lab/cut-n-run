#!/usr/bin/env nextflow
nextflow.enable.dsl=2

/*
 * DSL2 Implementation of Raab Lab CUT&RUN pipeline
 *
 * Authors:	Peyton Kuhlers <peyton_kuhlers@med.unc.edu>
 * 		Jesse Raab <jesse_raab@med.unc.edu>
 *
 */

// Define pipeline-wide params
params.sample_sheet		= ''
params.outdir			= 'Output'
params.create_samplesheet 	= ''
params.new_experiment		= ''
params.pull_samples		= ''
params.group_normalize		= ''
params.call_consensus_peaks	= false
params.mspc_args		= ''
params.help			= false
params.mode			= 'cnr'

// SRA acquisition params
params.sra_manifest		= ''
params.sra_max_size		= '100G'

// External-calibration params
params.host_fasta			= ''
params.external_calibration_fasta	= ''
params.combined_index_cache		= ''
params.calibration_alignment_mode	= 'local'

// import subworkflows

include { CREATE_SAMPLESHEET }				from './subworkflows/create_samplesheet'
include { CREATE_SAMPLESHEET as AT_CREATE_SS}		from './subworkflows/create_samplesheet'
include { CNR }						from './subworkflows/cnr'
include { CNR as AT_CNR }				from './subworkflows/cnr'
include { LOCAL_INPUT }					from './subworkflows/local_input'
include { LOCAL_INPUT as AT_LOCAL_INPUT }		from './subworkflows/local_input'
include { SRA_INPUT }					from './subworkflows/sra_input'

// import modules

include { pull_experiment; pull_samples }		from './modules/airtable'
include { update_paths }				from './modules/airtable'
include { helpMessage }					from './modules/functions'
include { validateRunParams }				from './modules/functions'

workflow {

	validateRunParams(params)

	if (params.help) {
		log.info helpMessage()
	}

	if (params.new_experiment) {
	// TODO: Get experiment IDs into the samplesheet
		pull_experiment(params.new_experiment) | AT_CREATE_SS | update_paths
	}


	if (params.pull_samples) {
		AT_LOCAL_INPUT(pull_samples(params.pull_samples))
		AT_CNR(AT_LOCAL_INPUT.out.reads)
	}

	if (params.create_samplesheet && params.sample_sheet) {
		exit 1, "ERROR: Conflicting samplesheet arguments. Choose one or the other."
	}

	if (params.create_samplesheet) {
		CREATE_SAMPLESHEET(params.create_samplesheet)
	}

	// Either input producer emits the same (meta, R1, R2) contract, so the
	// analysis workflow itself is not duplicated.
	if (params.sample_sheet) {
		LOCAL_INPUT(params.sample_sheet)
		CNR(LOCAL_INPUT.out.reads)
	}

	if (params.sra_manifest) {
		SRA_INPUT(params.sra_manifest)
		CNR(SRA_INPUT.out.reads)
	}
}
