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
params.sample_sheet	= ''
params.outdir		= 'Output'

// import Cut and Run modules

include { trim }	from './modules/qc'
include { picard_cis }	from './modules/qc'
include { bt2 }		from './modules/align'
include { sort }	from './modules/samtools'
include { macs }	from './modules/macs'
include { coverage }	from './modules/coverage'
include { multiqc }	from './modules/multiqc'

// Pull reads from sample sheet and set channel

def parse_samplesheet(LinkedHashMap row){
	def meta = [:]
	meta.id		= row.sample_name
	meta.lib_id	= row.lib_id
	meta.cell_line	= row.cell_line
	meta.ab		= row.ab

	def array = [meta, file(row.read1), file(row.read2) ]

	return array
}

Channel
	.fromPath(params.sample_sheet)
	.splitCsv(header:true)
	.map { parse_samplesheet(it) }
	.set { READS }

workflow CNR {

	main:

	// Trim reads
	trim(READS)

	// Align trimmed reads, generate bam file, collect insert sizes
	bt2(trim.out.trimmed, params.bt2_index)
	sort(bt2.out.bam)
	picard_cis(sort.out)

	// Call peaks
	macs(sort.out)

	// Compute coverage tracks (TODO: compute normalization factors for coverage)
	coverage(sort.out, 1)


	// Collect all QC outputs to multiqc
	multiqc(
		trim.out.fqc.collect(),
		bt2.out.stats.collect(),
		macs.out.stats.collect(),
		picard_cis.out.collect()
	)

}

workflow {
	CNR()
}
