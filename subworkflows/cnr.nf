// import Cut and Run modules

include { trim }				from '../modules/qc'
include { picard_cis }				from '../modules/qc'
include { picard_md }				from '../modules/qc'
include { picard_md_combined }			from '../modules/qc'
include { bt2 }					from '../modules/align'
include { bt2_combined }			from '../modules/align'
include { sort }				from '../modules/samtools'
include { sort as sort_combined }		from '../modules/samtools'
include { filter }				from '../modules/samtools'
include { filter as filter_host }		from '../modules/samtools'
include { partition_calibration_bam }		from '../modules/samtools'
include { build_combined_reference }		from '../modules/reference'
include { count_barcodes }			from '../modules/barcode'
include { host_pair_counts }			from '../modules/barcode'
include { barcode_calibration_summary }		from '../modules/barcode'
include { mapping_manifest }			from '../modules/reference'
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

	if(params.external_calibration_fasta) {

		// Competitive alignment against one combined reference. Host contigs
		// keep their names and order so their reference IDs stay valid when the
		// appended calibrator @SQ lines are stripped after partitioning.
		build_combined_reference(
			file(params.host_fasta),
			file(params.external_calibration_fasta),
			params.combined_index_cache
		)

		bt2_combined(
			trim.out.trimmed,
			build_combined_reference.out.index,
			params.calibration_alignment_mode
		)
		sort_combined(bt2_combined.out.bam)

		// Duplicates are marked exactly once, on the unfiltered combined BAM,
		// so host and calibrator fragments share one duplicate policy.
		picard_md_combined(sort_combined.out)

		partition_calibration_bam(picard_md_combined.out.bam, params.mapq)

		// The existing record-level filter still produces the host BAM used for
		// peaks and coverage. Note that it is record-level while the
		// normalization counts are pair-level: host and external counts must be
		// read from calibration_summary.tsv and cannot be reconstructed from
		// this filtered BAM.
		if(params.skip_filter) {
			host_marked_bam = partition_calibration_bam.out.bam
		} else {
			filter_host(partition_calibration_bam.out.bam, params.mapq, params.mode)
			host_marked_bam = filter_host.out
		}

		bam = host_marked_bam

		picard_cis(bam)

		// MACS2 and bamCoverage receive the host effective genome size, never
		// the combined reference length.
		macs(bam, params.genomeSize)

		// One mapping row per sample, carrying reference and alignment provenance
		mapping_manifest(
			partition_calibration_bam.out.bam.join(bt2_combined.out.args),
			build_combined_reference.out.manifest,
			params.calibration_alignment_mode,
			workflow.revision ?: workflow.commitId ?: 'unknown'
		)

		mapping_manifest.out.manifest
			.collectFile(name: 'mapping_manifest.tsv',
				     storeDir: "${params.outdir}/manifests",
				     keepHeader: true, skip: 1, sort: true)

		partition_calibration_bam.out.counts
			.collectFile(name: 'calibration_counts.tsv',
				     storeDir: "${params.outdir}/manifests",
				     keepHeader: true, skip: 1, sort: true)

		partition_calibration_bam.out.summary
			.collectFile(name: 'calibration_summary.tsv',
				     storeDir: "${params.outdir}/manifests",
				     keepHeader: true, skip: 1, sort: true)

		alignment_stats = bt2_combined.out.stats
		dup_metrics = picard_md_combined.out.metrics

	} else {

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

		host_marked_bam = picard_md.out.bam
		alignment_stats = bt2.out.stats
		dup_metrics = picard_md.out.metrics

		// Barcoded spike-in nucleosomes are counted by exact sequence match on
		// the untrimmed reads. The host path above is unchanged: only the
		// external measurement differs from a standard run.
		if(params.barcode_fasta) {
			count_barcodes(reads, file(params.barcode_fasta))
			host_pair_counts(host_marked_bam, params.mapq)

			barcode_calibration_summary(
				count_barcodes.out.summary.join(host_pair_counts.out.counts)
			)

			barcode_calibration_summary.out.summary
				.collectFile(name: 'calibration_summary.tsv',
					     storeDir: "${params.outdir}/manifests",
					     keepHeader: true, skip: 1, sort: true)

			count_barcodes.out.counts
				.collectFile(name: 'barcode_counts.tsv',
					     storeDir: "${params.outdir}/manifests",
					     keepHeader: true, skip: 1, sort: true)
		}
	}

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
	single_coverage(host_marked_bam, 1, params.genomeSize)

	// Collect all QC outputs to multiqc
	multiqc(
		trim.out.fqc.collect(),
		alignment_stats.collect(),
		macs.out.stats.collect(),
		picard_cis.out.collect(),
		dup_metrics.collect()
	)

	
	if(params.group_normalize){

		// Set a channel using the mark duped bams using user defined groupings
		host_marked_bam
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
