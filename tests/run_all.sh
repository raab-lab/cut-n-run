#!/usr/bin/env bash
# Run every test suite. From the repository root: bash tests/run_all.sh
#
# The Nextflow suites need `nextflow` on PATH; the calibration fixture also
# needs bowtie2, samtools and picard, and is skipped when they are absent.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

status=0
run() {
    local name=$1; shift
    printf '\n=== %s ===\n' "$name"
    if "$@"; then
        printf '  PASS: %s\n' "$name"
    else
        printf '  FAIL: %s\n' "$name"
        status=1
    fi
}

run "python unit tests"      python3 -m unittest discover -s tests -t . -q
run "SRA manifest (R)"       Rscript --vanilla tests/test_sra_manifest.R
run "FASTQ validation"       bash tests/test_sra_fastq_validation.sh

if command -v nextflow >/dev/null 2>&1; then
    run "CLI contract"       bash tests/test_cli_contract.sh
    run "SRA run grouping"   nextflow run tests/test_sra_grouping.nf -ansi-log false
else
    printf '\n  SKIP: Nextflow suites (nextflow not on PATH)\n'
fi

if command -v bowtie2 >/dev/null 2>&1 && command -v samtools >/dev/null 2>&1; then
    run "calibration fixture" bash tests/test_calibration_fixture.sh
else
    printf '\n  SKIP: calibration fixture (bowtie2/samtools not on PATH)\n'
fi

printf '\n'
[[ $status -eq 0 ]] && echo "ALL SUITES PASSED" || echo "SOME SUITES FAILED"
exit $status
