// Merge, sort, and index with samtools

process sort {
      label 'medium'
      tag "${meta.id}"
      publishDir "${params.outdir}/bams/sorted", mode: "copy"
      publishDir "${params.outdir}/${meta.id}/aligned/"
      module 'samtools/1.22'

      input:
      tuple val(meta), path(bam)

      output:
      tuple val(meta), path("*.aligned.sorted.bam"), path("*.aligned.sorted.bam.bai") 

      script:

      """
      samtools sort -@ ${task.cpus} ${bam} > ${meta.id}.aligned.sorted.bam
      samtools index ${meta.id}.aligned.sorted.bam
      """
   }

process filter {
	tag "${meta.id}"
	publishDir "${params.outdir}/bams/filtered", mode: "copy"
	publishDir "${params.outdir}/${meta.id}/aligned/"
	module 'bedtools/2.31.1'
	module 'samtools/1.22'

	when:
	!params.skip_filter

	input:
	tuple val(meta), path(bam), path(bai)
	val mapq
	val mode

	output:
	tuple val(meta), path("*filtered.sorted.bam"), path("*filtered.sorted.bam.bai")

	script:

	def mitoFilter = mode == 'atac' ? "-e 'rname != \"chrM\"'" : ""
	def exclusion = mode == 'atac' ? "| bedtools intersect -v -a stdin -b ${params.exclusionList}" : ""

	"""
	samtools view -b -q ${mapq} ${mitoFilter} ${bam} ${exclusion} > ${meta.id}_mapq${mapq}_filtered.sorted.bam

	samtools index ${meta.id}_mapq${mapq}_filtered.sorted.bam
	"""
}

// Partition a combined-reference alignment into its host and calibrator parts.
//
// Duplicates are already marked once on the combined BAM, so host and
// calibrator fragments carry the same duplicate policy. Only the host
// partition continues downstream, and it is reheadered so that no calibrator
// contig survives in either the records or the @SQ dictionary.

process partition_calibration_bam {
	label 'medium'
	tag "${meta.id}"
	module 'samtools/1.22'
	publishDir "${params.outdir}/bams/host", mode: "copy", pattern: "*.host.sorted.bam*"
	publishDir "${params.outdir}/manifests/calibration", mode: "copy", pattern: "*.tsv"

	input:
	tuple val(meta), path(bam), path(bai)
	val mapq

	output:
	tuple val(meta), path("${meta.id}.host.sorted.bam"), path("${meta.id}.host.sorted.bam.bai"), emit: bam
	path "${meta.id}.calibration_counts.tsv", emit: counts
	path "${meta.id}.calibration_summary.tsv", emit: summary

	script:
	"""
	set -euo pipefail

	samtools collate -u -O ${bam} | \\
		samtools view -h - | \\
		classify_calibration_pairs.py \\
			--sample-id "${meta.id}" \\
			--mapq "${mapq}" \\
			--calib-prefix calib__ \\
			--host-sam host.combined-header.sam \\
			--counts ${meta.id}.calibration_counts.tsv \\
			--summary ${meta.id}.calibration_summary.tsv

	samtools view -b host.combined-header.sam | \\
		samtools sort -@ ${task.cpus} -o host.combined-header.sorted.bam

	# Removing the records alone is not enough: the BAM header still declares
	# the full combined dictionary. Host contigs were written first, so
	# dropping the trailing calibrator @SQ lines keeps every reference ID valid
	# while preserving all non-@SQ header records.
	samtools view -H host.combined-header.sorted.bam | \\
		awk '\$1 != "@SQ" || \$0 !~ /SN:calib__/' > host.header.sam
	samtools reheader host.header.sam host.combined-header.sorted.bam > ${meta.id}.host.sorted.bam
	samtools index ${meta.id}.host.sorted.bam

	if samtools view -H ${meta.id}.host.sorted.bam | grep -q 'SN:calib__'; then
		echo "calibrator sequence remains in host BAM header" >&2
		exit 1
	fi
	if samtools view ${meta.id}.host.sorted.bam | cut -f3,7 | grep -q 'calib__'; then
		echo "calibrator reference remains in host BAM records" >&2
		exit 1
	fi
	"""
}
