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

// import Cut and Run modules

include { create_ss}	from './modules/create_samplesheet'
include { check_ss }	from './modules/check_samplesheet'
include { trim }	from './modules/qc'
include { picard_cis }	from './modules/qc'
include { picard_md }	from './modules/qc'
include { bt2 }		from './modules/align'
include { sort }	from './modules/samtools'
include { macs }	from './modules/macs'
include { normalize }	from './modules/normalize'
include { coverage }	from './modules/coverage'
include { multiqc }	from './modules/multiqc'

// Pull reads from sample sheet and set channel

def parse_samplesheet(LinkedHashMap row){
	def meta = [:]
	meta.id		= row.ID
	meta.lib_id	= row.lib_id
	meta.cell_line	= row.cell_line
	meta.ab		= row.antibody
	meta.trt	= row.treatment
	meta.rep	= row.replicate
	if(row.containsKey('group')) {
		meta.group = row.group
	}

	def array = [meta, file(row.read1), file(row.read2) ]

	return array
}

def parse_norm_factors(LinkedHashMap row) {
	def meta = [:]
	meta.id			= row.id
	meta.norm_factor	= row.scale_factors

	def array = [meta, file(row.bam), file(row.bai) ]

	return array
}

//Channel
//	.fromPath(params.sample_sheet)
//	.splitCsv(header:true)
//	.map { parse_samplesheet(it) }
//	.set { READS }

workflow CREATE_SAMPLESHEET {

	take:
	inventory

	main:

	create_ss(inventory)

	emit:
	create_ss.out

}
workflow CHECK_SAMPLES {

	main:

	// Check samplesheet columns and create unique ID
	check_ss(params.sample_sheet, 1)
	check_ss.out
		.splitCsv(header:true)
		.map { parse_samplesheet(it) }
		.set { READS }

	// Trim reads
	trim(READS)

	// Align trimmed reads, generate bam file, collect insert sizes
	bt2(trim.out.trimmed, params.bt2_index)
	sort(bt2.out.bam)
	picard_cis(sort.out)
	picard_md(sort.out)

	// Call peaks
	macs(sort.out)

	// First pass of coverage, no normalization
	coverage(picard_md.out.bam, 1)

	// Collect all QC outputs to multiqc
	multiqc(
		trim.out.fqc.collect(),
		bt2.out.stats.collect(),
		macs.out.stats.collect(),
		picard_cis.out.collect(),
		picard_md.out.metrics.collect()
	)

	emit:
	ss	= check_ss.out
	bam	= picard_md.out.bam

}

workflow ANALYZE {

	take:
	ss
	ch_bam

	main:

	// Check samplesheet columns and verify
	// TODO: this part should now require a grouping variable
	check_ss(ss, 2)
	check_ss.out
		.splitCsv(header:true)
		.map { parse_samplesheet(it) }
		.set { READS }

	// Set a channel using the mark duped bams from picard using user defined groupings
	ch_bam
	.map { row -> [ row[0].group, row[0], row[1], row[2] ] }
	.groupTuple(by: [0])
	.set { group_bams }

 	// Use dedup to compute scale factors and coverage
 	normalize(group_bams)
	normalize.out
	.splitCsv(header:true)
	.map { parse_norm_factors(it) }
	.set { norm_bams }

	coverage(norm_bams, 2)
}

workflow {
	if (params.create_samplesheet && params.sample_sheet) {
		exit 1, "ERROR: Conflicting samplesheet arguments. Choose one or the other."
	}

	if (params.create_samplesheet) {
		CREATE_SAMPLESHEET(params.create_samplesheet)
	}

	if (params.sample_sheet) {
		CHECK_SAMPLES()
		ANALYZE(CHECK_SAMPLES.out.ss, CHECK_SAMPLES.out.bam)
	}
}
