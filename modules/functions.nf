def helpMessage() { 
"""\
	==========================================================================================
	______            _       _           _       _____ _   _ _____      ______ _   _ _   _ 
	| ___ \\          | |     | |         | |     /  __ \\ | | |_   _|__   | ___ \\ | | | \\ | |
	| |_/ /__ _  __ _| |__   | |     __ _| |__   | /  \\/ | | | | |( _ )  | |_/ / | | |  \\| |
	|    // _` |/ _` | '_ \\  | |    / _` | '_ \\  | |   | | | | | |/ _ \\/\\|    /| | | | . ` |
	| |\\ \\ (_| | (_| | |_) | | |___| (_| | |_) | | \\__/\\ |_| | | | (_>  <| |\\ \\| |_| | |\\  |
	\\_| \\_\\__,_|\\__,_|_.__/  \\_____/\\__,_|_.__/   \\____/\\___/  \\_/\\___/\\/\\_| \\_|\\___/\\_| \\_/
	===========================================================================================
	\033[1;34mUsage\033[0m:
	nextflow run raab-lab/cut-n-run (--create_samplesheet|--sample_sheet) </path/>
	nextflow run raab-lab/cut-n-run (--new_experiment|--pull_samples) <ID>

	\033[1;34mArguments\033[0m:
	--help
		Display this message

	--create_samplesheet </path/>
		Path to a directory of fastq.gz files

	--sample_sheet </path/>
		Path to CSV with fastq paths and sample metadata
		Mutually exclusive with --sra_manifest

	--sra_manifest </path/>
		Path to a reviewed CSV with one row per SRR run accession.
		Required columns: Run, SampleID, Cell Line, Genotype, Antibody,
		Treatment, Replicate. Mutually exclusive with --sample_sheet.

	--sra_max_size <size>
		Maximum accession size accepted by prefetch [Default: 100G]
		Set explicitly on every invocation; prefetch's own default is 20G

	--new_experiment <ID>
		Experiment ID for new experiment to add to airtable

	--pull_samples <ID>
		Experiment ID to pull from airtable to run through pipeline

	--group_normalize
		Flag to normalize and average coverage tracks using group columns [Default: false]

	-w </path/>
		Path to your desired work directory for intermediate output [Default: work]

	--outdir </path/>
		Path to your desired output directory [Default: Output]

	\033[1;34mTool Options\033[0m:
	--mode <value>
		'cnr' or 'atac'. 'atac' adds mitochondrial read filtering and exclusion list filtering [Default: cnr]

	--exclusionList </path/>
		Path to ATACseq exclusion list [Default:/proj/jraablab/users/pkuhlers/seq_resources/hg38-exclusion.v3.bed]

	--bt2_index </path/>
		Path to Bowtie2 index [Default:/proj/seq/data/hg38_UCSC/Sequence/Bowtie2Index/]

	--bt2_cores <numeric>
		Number of cores used for alignment [Default: 8]

	--macs_qvalue <numeric>
		q-value cutoff for narrow peak calling [Default: 0.05]

	--broad <numeric>
		Flag for broad peak calling, must include a cutoff value [Default: off]

	--genomeSize <numeric>
		Effective genome size for MACS2 and bamCoverage (see docs for more info) [Default: 2701495761]

	--genome <value>
		Genome name to pull for chromosome sizes [Default: hg38]

	--norm_method <value>
		Normalization method for computing coverage scale factors. Either 'bins' or 'peaks' [Default: bins]

	--skip_filter
		Flag to skip filtering bam files by MAPQ (i.e. include all alignments)

	\033[1;34mExternal Calibration Options\033[0m:
	--host_fasta </path/>
		Path to the host genome FASTA. Required by --external_calibration_fasta

	--external_calibration_fasta </path/>
		Path to the external calibrator genome FASTA. Enables competitive
		alignment against a combined host + calibrator reference. Every
		calibrator contig is renamed with the reserved 'calib__' prefix.
		Requires --host_fasta.

	--combined_index_cache </path/>
		Optional shared directory for content-addressed combined Bowtie2
		indexes. Omit to build the index inside the run's work directory.

	--calibration_alignment_mode <value>
		'local' or 'end-to-end'. 'local' uses --very-sensitive-local and is
		the production setting. 'end-to-end' uses --very-sensitive and exists
		only for the documented sensitivity comparison. Valid only with
		--external_calibration_fasta [Default: local]

	--mapq <numeric>
		Only include alignments with MAPQ >= <numeric>

	\033[1;34mArguments to Always Include\033[0m:
	-profile <hg38 or mm10>
		Sets species specific variables [Default: hg38]

	-latest
		Flag to pull the latest pipeline release from GitHub

	-with-report
		Flag to output a run report

	-N <user@email.edu>
		Email address to notify when the pipeline has finished

	-resume
		Flag to pick back up from last pipeline execution (works even if first time)

""".stripIndent()

}

process fetch_chrom_sizes {
	tag "Fetch ${genome}"

	input:
	val(genome)

	output:
	path("${genome}.chrom.sizes")

	script:
	"""
	fetchChromSizes $genome > ${genome}.chrom.sizes
	"""
}

// Centralized run-parameter validation.
// Called before any file-backed channel is constructed so that contradictory
// command lines fail immediately rather than part-way through a run.
def validateRunParams(params) {
	if (params.sample_sheet && params.sra_manifest) {
		throw new IllegalArgumentException('--sample_sheet and --sra_manifest are mutually exclusive')
	}
	if (params.external_calibration_fasta && !params.host_fasta) {
		throw new IllegalArgumentException('--external_calibration_fasta requires --host_fasta')
	}
	if (!(params.calibration_alignment_mode in ['local', 'end-to-end'])) {
		throw new IllegalArgumentException('--calibration_alignment_mode must be local or end-to-end')
	}
	if (!params.external_calibration_fasta && params.calibration_alignment_mode != 'local') {
		throw new IllegalArgumentException('--calibration_alignment_mode is valid only with --external_calibration_fasta')
	}
	if (!params.sample_sheet && !params.sra_manifest && !params.create_samplesheet &&
		!params.new_experiment && !params.pull_samples && !params.help) {
		throw new IllegalArgumentException('provide --sample_sheet or --sra_manifest')
	}
}
