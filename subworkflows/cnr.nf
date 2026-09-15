// import Cut and Run modules

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

def parse_norm_factors(LinkedHashMap row) {
	def meta = [:]
	meta.id			= row.id
	meta.norm_factor	= row.scale_factors

	def array = [meta, file(row.bam), file(row.bai) ]

	return array
}

workflow CNR {

	take:
	reads

	main:

	// Trim reads
	trim(reads)

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
