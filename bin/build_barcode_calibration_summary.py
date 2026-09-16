#!/usr/bin/env python3
"""Assemble the standard calibration summary for a barcode spike-in sample.

The external count is the ON-TARGET barcode only: the panel member carrying the
same modification being profiled. Off-target members measure antibody
cross-reactivity, not the amount of spiked material the antibody should have
recovered, so summing the whole panel would mix a specificity measurement into
the size factor. This matches the established analysis for these panels.

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
    parser.add_argument("--barcode-counts", required=True,
                        help="per-barcode counts TSV from count_barcodes.py")
    parser.add_argument("--barcodes", required=True,
                        help="panel FASTA, whose headers carry target=<name>")
    parser.add_argument("--target", default="",
                        help="profiled modification, normally the sample's antibody")
    parser.add_argument("--host-counts", required=True,
                        help="classifier counts.tsv from the host-only BAM")
    parser.add_argument("--summary", required=True)
    args = parser.parse_args(argv)

    # barcode name -> target, from the panel FASTA headers
    targets = {}
    for line in open(args.barcodes):
        if line.startswith(">"):
            parts = line[1:].split()
            name = parts[0]
            tgt = next((p.split("=", 1)[1] for p in parts[1:] if p.startswith("target=")),
                       name.rsplit("_", 1)[0])
            targets[name] = tgt

    counts = {r["barcode"]: int(r["fragment_count"]) for r in read_tsv(args.barcode_counts)}
    total = sum(counts.values())
    if total <= 0:
        raise ValueError(
            f"{args.sample_id}: no barcode fragments were found. Check that the "
            f"panel FASTA matches the spike-in used and that counting ran on "
            f"untrimmed reads.")

    on_target = sum(v for name, v in counts.items()
                    if args.target and targets.get(name) == args.target)
    if on_target > 0:
        external = on_target
        basis = f"on_target:{args.target}"
    else:
        # A target absent from the panel (an IgG control, or a non-histone
        # antibody) has no on-target member. Fall back to the whole panel and
        # say so, rather than silently reporting a different quantity.
        external = total
        basis = "all_barcodes"
        print(f"{args.sample_id}: no on-target barcode for {args.target!r}; "
              f"using all {len(counts)} panel members", file=sys.stderr)

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
                  "duplicate_state\tcalibration_basis\ttotal_barcode_fragments\t"
                  "on_target_fraction\n")
        for threshold in sorted(host, key=int):
            host_n = host[threshold]
            classified = host_n + external
            fraction = external / classified if classified else float("nan")
            out.write(f"{args.sample_id}\t{host_n}\t{external}\t{classified}\t"
                      f"{fraction}\t{threshold}\tall\t{basis}\t{total}\t"
                      f"{external / total if total else float('nan')}\n")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print(f"{type(error).__name__}: {error}", file=sys.stderr)
        sys.exit(1)
