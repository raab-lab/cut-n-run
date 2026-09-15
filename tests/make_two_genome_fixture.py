#!/usr/bin/env python3
"""Generate a deterministic two-genome fixture for competitive alignment.

The read set is constructed so that every pair class is nonzero. That matters
because the two classes most easily broken, ``mixed`` and ``singleton``, fail
silently: suppressing Bowtie2's mixed/discordant modes or classifying on RNAME
instead of FLAG makes them read zero rather than error.

Emitted pairs:

* one unique proper host pair
* one unique proper calibrator pair
* one host-R1 / calibrator-R2 mixed pair
* one mapped-host-R1 / all-N-R2 singleton pair
* one all-N / all-N unmapped pair
* two identical proper host pairs, forming one duplicate set
"""

import argparse
import pathlib
import random

SEED = 228533
CONTIG_LENGTH = 2000
READ_LENGTH = 80
FRAGMENT = 300
COMPLEMENT = str.maketrans("ACGT", "TGCA")


def revcomp(sequence):
    return sequence.translate(COMPLEMENT)[::-1]


def wrap(sequence, width=60):
    return "\n".join(sequence[i:i + width] for i in range(0, len(sequence), width))


def fastq_record(name, sequence):
    return f"@{name}\n{sequence}\n+\n{'I' * len(sequence)}\n"


def proper_pair(genome, start):
    """Read1 forward at *start*, read2 reverse-complemented from downstream."""
    r1 = genome[start:start + READ_LENGTH]
    end = start + FRAGMENT
    r2 = revcomp(genome[end - READ_LENGTH:end])
    return r1, r2


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--outdir", required=True)
    args = parser.parse_args()

    out = pathlib.Path(args.outdir)
    out.mkdir(parents=True, exist_ok=True)

    rng = random.Random(SEED)
    host = "".join(rng.choice("ACGT") for _ in range(CONTIG_LENGTH))
    calib = "".join(rng.choice("ACGT") for _ in range(CONTIG_LENGTH))

    (out / "host.fa").write_text(">chrHost1\n" + wrap(host) + "\n")
    (out / "calibrator.fa").write_text(">chrCalib1\n" + wrap(calib) + "\n")

    r1_records = []
    r2_records = []

    def add(name, r1, r2):
        r1_records.append(fastq_record(name, r1))
        r2_records.append(fastq_record(name, r2))

    # Unique proper pairs, drawn from well-separated positions so that the two
    # genomes cannot be confused with each other.
    add("host_pair", *proper_pair(host, 200))
    add("calib_pair", *proper_pair(calib, 400))

    # Mixed: each mate is unique within its own genome.
    mixed_r1 = host[900:900 + READ_LENGTH]
    mixed_r2 = revcomp(calib[1200:1200 + READ_LENGTH])
    add("mixed_pair", mixed_r1, mixed_r2)

    # Singleton: read1 maps to the host, read2 cannot map anywhere.
    add("singleton_pair", host[1500:1500 + READ_LENGTH], "N" * READ_LENGTH)

    # Unmapped: neither mate can map.
    add("unmapped_pair", "N" * READ_LENGTH, "N" * READ_LENGTH)

    # Two identical proper host pairs form exactly one duplicate set.
    dup_r1, dup_r2 = proper_pair(host, 600)
    add("dup_pair_a", dup_r1, dup_r2)
    add("dup_pair_b", dup_r1, dup_r2)

    (out / "reads_1.fastq").write_text("".join(r1_records))
    (out / "reads_2.fastq").write_text("".join(r2_records))

    print(out)


if __name__ == "__main__":
    main()
