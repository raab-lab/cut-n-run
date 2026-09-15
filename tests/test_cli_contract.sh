#!/usr/bin/env bash
set -euo pipefail

expect_failure() {
    expected=$1
    shift
    if output=$(nextflow run . "$@" 2>&1); then
        echo "expected failure containing: ${expected}" >&2
        exit 1
    fi
    grep -F "$expected" <<<"$output"
}

expect_failure "mutually exclusive" \
    --sample_sheet local.csv --sra_manifest public.csv
expect_failure "requires --host_fasta" \
    --sra_manifest public.csv --external_calibration_fasta dm6.fa
expect_failure "local or end-to-end" \
    --sra_manifest public.csv --host_fasta hg38.fa \
    --external_calibration_fasta dm6.fa --calibration_alignment_mode invalid
expect_failure "valid only with --external_calibration_fasta" \
    --sample_sheet local.csv --calibration_alignment_mode end-to-end

echo "CLI contract OK"
