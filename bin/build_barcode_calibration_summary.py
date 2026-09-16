#!/usr/bin/env python3
"""Assemble the standard calibration summary for a barcode spike-in sample.

Barcode counts come from the FASTQs by exact match, so they carry no MAPQ and
no duplicate state: they are fragment counts before alignment. Host counts come
from the pair classifier and do vary with MAPQ. Rows are therefore emitted for
each MAPQ threshold at duplicate_state "all" only, which is the stratum the
normalization importer selects, rather than inventing deduplicated barcode
counts that were never measured.
"""

import argparse
import csv
import sys


def read_tsv(path):
    with open(path, newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sample-id", required=True)
    parser.add_argument("--barcode-summary", required=True)
    parser.add_argument("--host-counts", required=True,
                        help="classifier counts.tsv from the host-only BAM")
    parser.add_argument("--summary", required=True)
    args = parser.parse_args(argv)

    barcode_rows = read_tsv(args.barcode_summary)
    if len(barcode_rows) != 1:
        raise ValueError(f"expected one barcode summary row, got {len(barcode_rows)}")
    external = int(barcode_rows[0]["barcode_fragments"])
    if external <= 0:
        raise ValueError(
            f"{args.sample_id}: no barcode fragments were found. Check that the "
            f"panel FASTA matches the spike-in used and that counting ran on "
            f"untrimmed reads.")

    host = {}
    for row in read_tsv(args.host_counts):
        if (row["pair_class"] == "both_host" and row["proper_pair"] == "true"
                and row["duplicate_state"] == "all"):
            host[row["mapq_threshold"]] = int(row["fragment_count"])
    if not host:
        raise ValueError("no proper both_host rows found in the host counts table")

    with open(args.summary, "w") as out:
        out.write("SampleID\thost_fragments\texternal_fragments\t"
                  "classified_fragments\texternal_fraction\tmapq_threshold\t"
                  "duplicate_state\n")
        for threshold in sorted(host, key=int):
            host_n = host[threshold]
            classified = host_n + external
            fraction = external / classified if classified else float("nan")
            out.write(f"{args.sample_id}\t{host_n}\t{external}\t{classified}\t"
                      f"{fraction}\t{threshold}\tall\n")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print(f"{type(error).__name__}: {error}", file=sys.stderr)
        sys.exit(1)
