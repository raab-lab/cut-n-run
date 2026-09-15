#!/usr/bin/env bash
# Verification for post-conversion FASTQ validation.
# Run from the repository root: bash tests/test_sra_fastq_validation.sh
set -uo pipefail

RUN=SRR10000001
FIX=tests/fixtures/sra_fastq
VALIDATE=bin/validate_sra_fastqs.sh

fail() { echo "FAIL: $*" >&2; exit 1; }

# A valid pair exits zero and reports the documented fields.
if ! out=$(bash "$VALIDATE" "$RUN" "$FIX/valid" 2>&1); then
    fail "valid fixture rejected: $out"
fi
header=$(head -n 1 <<<"$out")
expected_header=$'Run\tR1_records\tR2_records\tR1_bytes\tR2_bytes'
[[ "$header" == "$expected_header" ]] || fail "bad header: $(cat -A <<<"$header")"

row=$(sed -n '2p' <<<"$out")
IFS=$'\t' read -r f_run f_r1 f_r2 f_b1 f_b2 <<<"$row"
[[ "$f_run" == "$RUN" ]]  || fail "Run field was '$f_run'"
[[ "$f_r1" == "2" ]]      || fail "R1_records was '$f_r1', expected 2"
[[ "$f_r2" == "2" ]]      || fail "R2_records was '$f_r2', expected 2"
[[ "$f_b1" -gt 0 ]]       || fail "R1_bytes was '$f_b1'"
[[ "$f_b2" -gt 0 ]]       || fail "R2_bytes was '$f_b2'"

# Each invalid fixture must exit nonzero with its documented message.
expect_rejection() {
    local dir=$1 pattern=$2 out rc
    out=$(bash "$VALIDATE" "$RUN" "$FIX/$dir" 2>&1)
    rc=$?
    (( rc != 0 )) || fail "$dir fixture was accepted"
    grep -qF "$pattern" <<<"$out" || fail "$dir did not report '$pattern', got: $out"
}

expect_rejection unequal   "unequal mate counts"
expect_rejection truncated "not divisible by four"
expect_rejection extra     "unexpected FASTQ output"

echo "SRA FASTQ validation OK"
