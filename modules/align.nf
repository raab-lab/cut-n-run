// Alignment

process bt2 {
	tag "$meta.id"
	cpus "${params.bt2_cores}"
	memory '8GB'
	time '24h'
	publishDir "${params.outdir}/bams", mode: "copy"
	publishDir "${params.outdir}/${meta.id}/aligned/"

	module 'bowtie2/2.5.4'
	module 'samtools/1.22'

	input:
	tuple val(meta), path(fq1), path(fq2)
	path index

	output:
	tuple val(meta), path("*aligned.bam"), emit: bam
	path "*.alignment_stats.txt", emit: stats

	script:

	"""
	bowtie2 \\
		-x ${index}/genome \\
		-p ${task.cpus} \\
		--very-sensitive-local \\
		-X 800 \\
		-1 $fq1 \\
		-2 $fq2 \\
		2>${meta.id}.alignment_stats.txt |\\
		samtools view -b > ${meta.id}.aligned.bam
	"""
}

// Competitive alignment against a combined host + calibrator reference.
//
// The default mixed and discordant search modes are required, not incidental:
// with --no-mixed or --no-discordant, Bowtie2 would never emit the half-mapped
// and cross-reference alignments that the singleton and mixed pair classes are
// there to measure, making both categories structurally zero.

process bt2_combined {
	tag "$meta.id"
	cpus "${params.bt2_cores}"
	memory '16GB'
	time '24h'
	publishDir "${params.outdir}/${meta.id}/aligned/"

	module 'bowtie2/2.5.4'
	module 'samtools/1.22'

	input:
	tuple val(meta), path(fq1), path(fq2)
	path index
	val alignment_mode

	output:
	tuple val(meta), path("*combined.bam"), emit: bam
	path "*.alignment_stats.txt", emit: stats
	tuple val(meta), path("*.bt2_args.txt"), emit: args

	script:
	def preset = alignment_mode == 'local' ? '--very-sensitive-local' : '--very-sensitive'
	def args = "${preset} -X 800"
	if (args.tokenize().any { it in ['--no-mixed', '--no-discordant'] }) {
		error 'Calibration alignment cannot suppress mixed or discordant output'
	}
	"""
	set -euo pipefail

	printf '%s\\n' "${args}" > ${meta.id}.bt2_args.txt
	bowtie2 --version | head -n 1 >> ${meta.id}.bt2_args.txt

	bowtie2 \\
		-x ${index}/genome \\
		-p ${task.cpus} \\
		${args} \\
		-1 $fq1 \\
		-2 $fq2 \\
		2>${meta.id}.alignment_stats.txt |\\
		samtools view -b > ${meta.id}.combined.bam
	"""
}
