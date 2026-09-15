// SRA input producer.
//
// Takes a reviewed one-row-per-SRR manifest, retrieves and verifies each run,
// merges runs belonging to the same biological library, and emits the same
// (meta, R1, R2) tuple contract as the local-FASTQ producer.

include { check_sra_manifest }	from '../modules/sra'
include { prefetch_sra }		from '../modules/sra'
include { convert_sra }		from '../modules/sra'
include { merge_sra_runs }	from '../modules/sra'

def parse_sra_manifest(LinkedHashMap row){
	def meta = [:]
	meta.sampleNum	= row.containsKey('SampleNumber') ? row.SampleNumber : row.SampleID
	meta.id		= row.SampleID
	meta.lib_id	= row.SampleID
	meta.cell_line	= row["Cell Line"]
	meta.ab		= row.Antibody
	meta.geno	= row.Genotype
	meta.trt	= row.Treatment
	meta.rep	= row.Replicate
	meta.layout	= row.LibraryLayout
	meta.platform	= row.Platform
	if(row.containsKey('group_norm')) {
		meta.group_norm = row.group_norm
	}
	if(row.containsKey('group_avg')) {
		meta.group_avg = row.group_avg
	}
	if(row.containsKey('params')) {
		meta.norm_params = row.params
	}

	return [ meta, row.Run ]
}

workflow SRA_INPUT {

	take:
	manifest

	main:

	// Reject contradictory or unsupported manifests before any download starts
	check_sra_manifest(manifest)

	check_sra_manifest.out.manifest
		.splitCsv(header:true)
		.map { parse_sra_manifest(it) }
		.set { RUNS }

	// One independent task per run accession
	prefetch_sra(RUNS, params.sra_max_size)
	convert_sra(prefetch_sra.out.archive, params.sra_max_size)

	// Merge runs belonging to one library in stable accession order. Samples
	// with a single run take the same path so filenames stay uniform.
	convert_sra.out.reads
		.map { meta, run, r1, r2 -> [ meta.id, meta, run, r1, r2 ] }
		.groupTuple(by: 0)
		.map { id, metas, runs, r1s, r2s ->
			def order = (0..<runs.size()).sort { runs[it] }
			[ metas[0],
			  order.collect { runs[it] },
			  order.collect { r1s[it] },
			  order.collect { r2s[it] } ]
		}
		.set { GROUPED }

	merge_sra_runs(GROUPED)

	// One acquisition row per run, with a single header
	convert_sra.out.acquisition
		.collectFile(name: 'sra_acquisition_manifest.tsv',
			     storeDir: "${params.outdir}/manifests",
			     keepHeader: true,
			     skip: 1,
			     sort: true)
		.set { ACQUISITION }

	emit:
	reads		= merge_sra_runs.out.reads
	acquisition	= ACQUISITION
}
