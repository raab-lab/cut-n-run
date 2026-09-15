// Local FASTQ input producer.
//
// This is the unchanged default path: it checks the sample sheet, generates the
// unique IDs the rest of the pipeline expects, and emits the (meta, R1, R2)
// tuple contract shared with the SRA producer.

include { check_ss as check1 }	from '../modules/check_samplesheet'
include { check_ss as check2 }	from '../modules/check_samplesheet'

def parse_samplesheet(LinkedHashMap row){
	def meta = [:]
	meta.sampleNum	= row.SampleNumber
	meta.id		= row.ID
	meta.lib_id	= row.SampleID
	meta.cell_line	= row["Cell Line"]
	meta.ab		= row.Antibody
	meta.geno	= row.Genotype
	meta.trt	= row.Treatment
	meta.rep	= row.Replicate
	if(row.containsKey('group_norm')) {
		meta.group_norm = row.group_norm
	}
	if(row.containsKey('group_avg')) {
		meta.group_avg = row.group_avg
	}
	if(row.containsKey('params')) {
		meta.norm_params = row.params
	}

	def array = [meta, file(row.R1), file(row.R2) ]

	return array
}

workflow LOCAL_INPUT {

	take:
	samplesheet

	main:

	// Check samplesheet columns and create unique ID
	check1(samplesheet, "single")
	check1.out
		.splitCsv(header:true)
		.map { parse_samplesheet(it) }
		.set { READS }

	// Verify the grouping columns exist before any alignment work is done
	if(params.group_normalize){
		check2(samplesheet, "group")
	}

	emit:
	reads = READS
}
