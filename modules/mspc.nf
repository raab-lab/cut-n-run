// Consensus peak calling with MSPC

// Call consensus peaks across replicates
process mspc {
	label 'medium'
	tag "$group_id"
	publishDir "${params.outdir}/peaks/consensus_peaks/", mode: "copy"
	publishDir "${params.outdir}/${group_id}/consensus_peaks/", mode: "copy"

	input:
	tuple val(group_id), val(metas), path(peaks)

	output:
	tuple val(group_id), path("${group_id}_ConsensusPeaks.bed"), emit: consensus
	path "session_*", emit: session_dir

	script:
	def mspc_args = params.mspc_args ?: ""
	def weak_threshold = params.mspc_weak ?: 0.0001
	def strong_threshold = params.mspc_strong ?: 1e-08
	def gamma = params.mspc_gamma ?: 1e-12
	def score_cutoff = params.mspc_score_cutoff ?: 30
	def min_overlap = params.mspc_min_overlap ?: 1

	"""
	# Convert narrowPeak to BED format for MSPC input
	for peak_file in ${peaks.join(' ')}; do
		# Extract sample name from peak file
		sample_name=\$(basename \$peak_file | sed 's/_peaks.narrowPeak//')
		# Convert narrowPeak to BED format (first 4 columns: chr, start, end, name)
		awk 'OFS="\\t" {print \$1, \$2, \$3, \$4"_"\$10}' \$peak_file > \${sample_name}.bed
	done

	# Download MSPC if not available
	if ! command -v mspc &> /dev/null; then
		wget -q https://github.com/Genometric/MSPC/releases/download/v5.2.3/MSPC-v5.2.3-linux-x64.zip
		unzip -q MSPC-v5.2.3-linux-x64.zip
		chmod +x mspc
		MSPC_CMD="./mspc"
	else
		MSPC_CMD="mspc"
	fi

	# Run MSPC with parameters
	\$MSPC_CMD -i *.bed \\
		-r bio \\
		-w $weak_threshold \\
		-s $strong_threshold \\
		-g $gamma \\
		-c $min_overlap \\
		$mspc_args

	# Rename consensus peaks file to include group ID
	find . -name "ConsensusPeaks.bed" -exec cp {} ${group_id}_ConsensusPeaks.bed \\;
	"""
}
