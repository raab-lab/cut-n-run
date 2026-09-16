#!/usr/bin/env python3
"""Count barcoded spike-in nucleosome reads by exact sequence match.

Designer-nucleosome panels (SNAP-ChIP / SNAP-CUTANA K-MetStat and similar)
share a common Widom 601 backbone and differ only in a short barcode, so
aligning them competitively gives nearly every spike-in read MAPQ 0-1 and a
MAPQ filter discards the calibration signal entirely. The vendor protocols
therefore count these by exact barcode match, which is what this does.

Counting happens on the merged, untrimmed FASTQs: trimming can clip a barcode
that sits near a read end, which would silently reduce the calibration count.

A fragment is counted once. When both mates contain a barcode they must agree,
otherwise the fragment is counted as ambiguous and excluded.
"""

import argparse
import collections
import gzip
import io
import sys

COMPLEMENT = str.maketrans("ACGTNacgtn", "TGCANtgcan")


def revcomp(seq):
    return seq.translate(COMPLEMENT)[::-1]


def read_fasta(path):
    """Return {name: sequence} for the barcode panel."""
    entries = {}
    name = None
    chunks = []
    with open(path) as handle:
        for line in handle:
            line = line.strip()
            if line.startswith(">"):
                if name is not None:
                    entries[name] = "".join(chunks).upper()
                name = line[1:].split()[0]
                chunks = []
            elif line:
                chunks.append(line)
    if name is not None:
        entries[name] = "".join(chunks).upper()
    if not entries:
        raise ValueError(f"no barcode sequences found in {path}")
    blank = [n for n, s in entries.items() if not s]
    if blank:
        raise ValueError(f"barcode(s) with no sequence: {', '.join(sorted(blank))}")
    return entries


def open_fastq(path):
    if str(path).endswith(".gz"):
        return io.TextIOWrapper(gzip.open(path, "rb"))
    return open(path)


def iter_sequences(path):
    """Yield the sequence line of every FASTQ record."""
    with open_fastq(path) as handle:
        for index, line in enumerate(handle):
            if index % 4 == 1:
                yield line.strip().upper()


def find_barcode(sequence, patterns):
    """Return the single barcode present in *sequence*, or None/AMBIGUOUS."""
    hits = {name for name, variants in patterns.items()
            if any(v in sequence for v in variants)}
    if not hits:
        return None
    if len(hits) > 1:
        return "__AMBIGUOUS__"
    return hits.pop()


def count_barcodes(r1_path, r2_path, barcodes):
    """Count fragments carrying each barcode, matching either orientation."""
    patterns = {name: (seq, revcomp(seq)) for name, seq in barcodes.items()}
    counts = collections.Counter()
    total = 0
    ambiguous = 0
    matched = 0

    for s1, s2 in zip(iter_sequences(r1_path), iter_sequences(r2_path)):
        total += 1
        b1 = find_barcode(s1, patterns)
        b2 = find_barcode(s2, patterns)
        found = {b for b in (b1, b2) if b is not None}
        if not found:
            continue
        if "__AMBIGUOUS__" in found or len(found) > 1:
            # Mates disagree, or one mate matched two panel members.
            ambiguous += 1
            continue
        counts[found.pop()] += 1
        matched += 1

    return {"per_barcode": counts, "total_fragments": total,
            "barcode_fragments": matched, "ambiguous_fragments": ambiguous}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sample-id", required=True)
    parser.add_argument("--barcodes", required=True, help="FASTA of panel barcode sequences")
    parser.add_argument("--r1", required=True)
    parser.add_argument("--r2", required=True)
    parser.add_argument("--counts", required=True, help="per-barcode output TSV")
    parser.add_argument("--summary", required=True, help="one-row sample summary TSV")
    args = parser.parse_args(argv)

    barcodes = read_fasta(args.barcodes)
    result = count_barcodes(args.r1, args.r2, barcodes)

    with open(args.counts, "w") as out:
        out.write("SampleID\tbarcode\tfragment_count\n")
        for name in sorted(barcodes):
            out.write(f"{args.sample_id}\t{name}\t{result['per_barcode'].get(name, 0)}\n")

    total = result["total_fragments"]
    external = result["barcode_fragments"]
    fraction = external / total if total else float("nan")
    with open(args.summary, "w") as out:
        out.write("SampleID\ttotal_fragments\tbarcode_fragments\tambiguous_fragments\t"
                  "barcode_fraction\tn_barcodes\n")
        out.write(f"{args.sample_id}\t{total}\t{external}\t{result['ambiguous_fragments']}\t"
                  f"{fraction}\t{len(barcodes)}\n")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print(f"{type(error).__name__}: {error}", file=sys.stderr)
        sys.exit(1)
