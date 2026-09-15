#!/usr/bin/env bash
# Deterministic end-to-end coverage of competitive alignment and partitioning.
#
# Exercises the production helpers, not reimplementations: the combined
# reference builder, the pair classifier, and the same reheader sequence the
# partition process uses. Every pair class must be nonzero, because the classes
# most easily broken read zero rather than erroring.
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WORK=${CNR_FIXTURE_WORK:-$(mktemp -d)}
mkdir -p "$WORK"
MAPQ=${CNR_FIXTURE_MAPQ:-10}
SAMPLE=fixture

# Pinned on Longleaf; locally whatever is on PATH is used and reported.
if command -v module >/dev/null 2>&1; then
    module load bowtie2/2.5.4 samtools/1.22 picard/2.26.11 || true
fi

bowtie2_version=$(bowtie2 --version | head -n 1 | awk '{print $NF}')
bowtie2_args="--very-sensitive-local -X 800"

fail() {
    echo "FAIL: $*" >&2
    echo "  Bowtie2 version: ${bowtie2_version}" >&2
    echo "  Bowtie2 args:    ${bowtie2_args}" >&2
    exit 1
}

cd "$WORK"
python3 "$REPO/tests/make_two_genome_fixture.py" --outdir "$WORK/fixture" >/dev/null

# Production combined-reference builder, including contig renaming and ordering.
python3 "$REPO/bin/build_combined_reference.py" \
    --host "$WORK/fixture/host.fa" \
    --external "$WORK/fixture/calibrator.fa" \
    --output-dir "$WORK/combined_index" >/dev/null 2>&1 \
    || fail "combined reference build failed"

# Exact production argument string; mixed and discordant modes stay enabled.
# shellcheck disable=SC2086
bowtie2 -x "$WORK/combined_index/genome" -p 1 $bowtie2_args \
    -1 "$WORK/fixture/reads_1.fastq" -2 "$WORK/fixture/reads_2.fastq" \
    2> "$WORK/alignment_stats.txt" \
    | samtools view -b > "$WORK/combined.bam"

samtools sort -o "$WORK/combined.sorted.bam" "$WORK/combined.bam"
samtools index "$WORK/combined.sorted.bam"

# Duplicates are marked once, on the combined alignment, before partitioning.
if command -v picard >/dev/null 2>&1; then
    picard MarkDuplicates I="$WORK/combined.sorted.bam" \
        O="$WORK/combined_markdup.bam" M="$WORK/combined_dup_metrics.txt" \
        REMOVE_DUPLICATES=false CREATE_INDEX=true >/dev/null 2>&1 \
        || fail "MarkDuplicates failed"
else
    samtools markdup -f "$WORK/markdup_stats.txt" \
        <(samtools collate -u -O "$WORK/combined.sorted.bam" | samtools fixmate -m - - | samtools sort -) \
        "$WORK/combined_markdup.bam" >/dev/null 2>&1 \
        || fail "samtools markdup failed"
    samtools index "$WORK/combined_markdup.bam"
fi

samtools collate -u -O "$WORK/combined_markdup.bam" \
    | samtools view -h - \
    | python3 "$REPO/bin/classify_calibration_pairs.py" \
        --sample-id "$SAMPLE" --mapq "$MAPQ" --calib-prefix calib__ \
        --host-sam "$WORK/host.combined-header.sam" \
        --counts "$WORK/calibration_counts.tsv" \
        --summary "$WORK/calibration_summary.tsv" \
    || fail "classification failed"

# Same reheader sequence as partition_calibration_bam.
samtools view -b "$WORK/host.combined-header.sam" \
    | samtools sort -o "$WORK/host.combined-header.sorted.bam"
samtools view -H "$WORK/host.combined-header.sorted.bam" \
    | awk '$1 != "@SQ" || $0 !~ /SN:calib__/' > "$WORK/host.header.sam"
samtools reheader "$WORK/host.header.sam" "$WORK/host.combined-header.sorted.bam" \
    > "$WORK/host.sorted.bam"
samtools index "$WORK/host.sorted.bam"

# Every pair class must be nonzero.
for class in both_host both_calib mixed singleton unmapped; do
    awk -F '\t' -v class="$class" '
        NR > 1 && $2 == class && $3 == "NA" && $4 == "NA" && $5 == "all" && $6 > 0 { found=1 }
        END { exit !found }
    ' "$WORK/calibration_counts.tsv" || fail "missing nonzero class ${class}"
done

# No calibrator sequence may survive in the host BAM, in records or header.
if samtools view -H "$WORK/host.sorted.bam" | grep -q 'SN:calib__'; then
    fail "calibrator sequence remains in host BAM header"
fi
if samtools view "$WORK/host.sorted.bam" | cut -f3,7 | grep -q 'calib__'; then
    fail "calibrator reference remains in host BAM records"
fi

# Reviewed expected tables.
if [[ -n "${CNR_FIXTURE_RECORD:-}" ]]; then
    mkdir -p "$REPO/tests/expected"
    cp "$WORK/calibration_counts.tsv" "$REPO/tests/expected/calibration_counts.tsv"
    cp "$WORK/calibration_summary.tsv" "$REPO/tests/expected/calibration_summary.tsv"
    echo "recorded expected tables from ${WORK}"
else
    diff -u "$REPO/tests/expected/calibration_counts.tsv" "$WORK/calibration_counts.tsv" \
        || fail "calibration_counts.tsv differs from the reviewed expectation"
    diff -u "$REPO/tests/expected/calibration_summary.tsv" "$WORK/calibration_summary.tsv" \
        || fail "calibration_summary.tsv differs from the reviewed expectation"
fi

echo "calibration fixture OK (bowtie2 ${bowtie2_version}, args: ${bowtie2_args})"
echo "WORK=${WORK}"
