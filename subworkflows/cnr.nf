// import Cut and Run modules

include { check_ss as check1}			from '../modules/check_samplesheet'
include { check_ss as check2}			from '../modules/check_samplesheet'
include { trim }				from '../modules/qc'
include { picard_cis }				from '../modules/qc'
include { picard_md }				from '../modules/qc'
include { bt2 }					from '../modules/align'
include { sort }				from '../modules/samtools'
include { filter }				from '../modules/samtools'
include { macs }				from '../modules/macs'
include { mspc }				from '../modules/mspc'
include { normalize }				from '../modules/normalize'
include { coverage as single_coverage }		from '../modules/coverage'
include { coverage as group_coverage }		from '../modules/coverage'
include { average }				from '../modules/average'
include { fetch_chrom_sizes }			from '../modules/functions'
include { multiqc }				from '../modules/multiqc'

// Define parsing functions

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

	if(params.skip_filter) {
		bam = sort.out

	} else {
		filter(sort.out, params.mapq, params.mode)
		bam = filter.out
	}

	picard_cis(bam)
	picard_md(bam)

	// Call peaks
	macs(bam, params.genomeSize)

	// Call consensus peaks if enabled
	if(params.call_consensus_peaks){
		// Group peaks by group_avg for consensus calling
		macs.out.peaks
			.map { meta, peaks -> [ meta.group_avg, meta, peaks ] }
			.groupTuple(by: [0])
			.filter { group_id, metas, peak_files -> peak_files.size() >= 2 }
			.set { grouped_peaks }

		mspc(grouped_peaks)
	}

	// First pass of coverage, no normalization
	single_coverage(picard_md.out.bam, 1, params.genomeSize)

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
			.map { row -> [ row[0].group_norm, row[0], row[1], row[2] ] }
			.groupTuple(by: [0])
			.set { group_bams }

		// Use dedup to compute scale factors and coverage
		normalize(group_bams)
		normalize.out.norm_factors
			.splitCsv(header:true)
			.map { parse_norm_factors(it) }
			.set { norm_bams }

		normalize.out.meta
			.flatten()
			.map { row -> [ row.id, row.group_avg ] }
			.set { norm_meta }

		group_coverage(norm_bams, 2, params.genomeSize)

		// Set a channel for scaled bw from group_coverage this average over the user defined groupings (different from normalization group!!)
		// Implementing this is a mess
		group_coverage.out
			.map { row -> [ row[0].id, row[1] ] }
			.join(norm_meta, failOnMismatch: true)
			.groupTuple(by: [2])
			.set { group_bw }

		// Use scaled bw to compute average coverage
		// Fetch chrom sizes to feed to wigToBigWig
		fetch_chrom_sizes(params.genome)
		average(group_bw, fetch_chrom_sizes.out)

	}
}
