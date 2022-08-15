// import Cut and Run modules

include { check_ss as check1}			from '../modules/check_samplesheet'
include { check_ss as check2}			from '../modules/check_samplesheet'
include { trim }				from '../modules/qc'
include { picard_cis }				from '../modules/qc'
include { picard_md }				from '../modules/qc'
include { bt2 }					from '../modules/align'
include { sort }				from '../modules/samtools'
include { macs }				from '../modules/macs'
include { normalize }				from '../modules/normalize'
include { coverage as single_coverage }		from '../modules/coverage'
include { coverage as group_coverage }		from '../modules/coverage'
include { multiqc }				from '../modules/multiqc'

// Define parsing functions

def parse_samplesheet(LinkedHashMap row){
	def meta = [:]
	meta.id		= row.ID
	meta.lib_id	= row.SampleID
	meta.cell_line	= row["Cell Line"]
	meta.ab		= row.Antibody
	meta.trt	= row.Treatment
	meta.rep	= row.Replicate
	if(row.containsKey('group')) {
		meta.group = row.group
	}

	def array = [meta, file(row.R1), file(row.R2) ]

	return array
}

def parse_norm_factors(LinkedHashMap row) {
	def meta = [:]
	meta.id			= row.id
	meta.norm_factor	= row.scale_factors

	def array = [meta, file(row.bam), file(row.bai) ]

	return array
}

workflow CNR {

	take:
	samplesheet

	main:

	// Check samplesheet columns and create unique ID
	check1(samplesheet, "single")
	check1.out
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
	single_coverage(picard_md.out.bam, 1)

	// Collect all QC outputs to multiqc
	multiqc(
		trim.out.fqc.collect(),
		bt2.out.stats.collect(),
		macs.out.stats.collect(),
		picard_cis.out.collect(),
		picard_md.out.metrics.collect()
	)

	
	if(params.group_normalize){

		// Check samplesheet columns and verify group present
		check2(samplesheet, "group")
		check2.out
			.splitCsv(header:true)
			.map { parse_samplesheet(it) }
			.set { READS }

		// Set a channel using the mark duped bams from picard using user defined groupings
		picard_md.out.bam
			.map { row -> [ row[0].group, row[0], row[1], row[2] ] }
			.groupTuple(by: [0])
			.set { group_bams }

		// Use dedup to compute scale factors and coverage
		normalize(group_bams)
		normalize.out
			.splitCsv(header:true)
			.map { parse_norm_factors(it) }
			.set { norm_bams }

		group_coverage(norm_bams, 2)

	}
}
