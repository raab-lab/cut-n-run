#!/usr/bin/env bash
# Validate the FASTQ pair produced by fasterq-dump for one SRA run.
#
# SRA layout metadata is only a preflight filter; these post-conversion checks
# are the authoritative guard that a run really is usable paired-end data.
# Usage: validate_sra_fastqs.sh <run> <outdir>
set -euo pipefail

run=${1:?usage: validate_sra_fastqs.sh <run> <outdir>}
outdir=${2:?usage: validate_sra_fastqs.sh <run> <outdir>}

shopt -s nullglob
files=("${outdir}/${run}"*.fastq)
expected=("${outdir}/${run}_1.fastq" "${outdir}/${run}_2.fastq")

# --split-files emits a third file for unmated reads without complaining, so
# anything other than exactly the two mates is a rejection rather than a warning.
[[ ${#files[@]} -eq 2 ]] || { echo "unexpected FASTQ output" >&2; exit 1; }
[[ -s ${expected[0]} && -s ${expected[1]} ]] || { echo "missing or empty mate" >&2; exit 1; }

r1_lines=$(wc -l < "${expected[0]}")
r2_lines=$(wc -l < "${expected[1]}")
(( r1_lines % 4 == 0 && r2_lines % 4 == 0 )) || {
    echo "FASTQ line count not divisible by four" >&2; exit 1;
}
[[ $r1_lines -eq $r2_lines ]] || { echo "unequal mate counts" >&2; exit 1; }

r1_bytes=$(wc -c < "${expected[0]}")
r2_bytes=$(wc -c < "${expected[1]}")

printf 'Run\tR1_records\tR2_records\tR1_bytes\tR2_bytes\n'
printf '%s\t%d\t%d\t%d\t%d\n' \
    "$run" "$(( r1_lines / 4 ))" "$(( r2_lines / 4 ))" "$r1_bytes" "$r2_bytes"
