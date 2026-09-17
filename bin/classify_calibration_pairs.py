#!/usr/bin/env python3
"""Classify name-collated primary read pairs by reference origin.

Reads SAM on stdin and writes the host partition plus the calibration count
tables. Three properties matter and are enforced here rather than assumed:

* Mapping status comes from FLAG 0x4, never from RNAME. An unmapped mate is
  written with its mapped partner's RNAME and POS, so a classifier that reads
  reference names would call a half-mapped pair ``both_host``.
* Pairs are classified before FLAG 0x2 is consulted. A pair whose mates map to
  different references is never a proper pair, so measuring ``mixed`` among
  proper pairs alone would make the category structurally zero.
* Only ``both_host`` pairs reach the host SAM. Mixed and singleton pairs are
  QC-only and never enter the host feature universe.

The emitted host SAM keeps the combined header; the caller strips the trailing
calibrator ``@SQ`` lines, which is valid only because host contigs come first
and therefore keep their numeric reference IDs.
"""

import argparse
import sys

FLAG_PAIRED = 0x1
FLAG_PROPER = 0x2
FLAG_UNMAPPED = 0x4
FLAG_MATE_UNMAPPED = 0x8
FLAG_READ1 = 0x40
FLAG_SECONDARY = 0x100
FLAG_DUPLICATE = 0x400
FLAG_SUPPLEMENTARY = 0x800

DUPLICATE_STATES = ("all", "nonduplicate")
CLASSES = ("both_host", "both_calib", "mixed", "singleton", "unmapped")


class Record:
    __slots__ = ("qname", "flag", "rname", "mapq", "line")

    def __init__(self, line):
        fields = line.rstrip("\n").split("\t")
        self.qname = fields[0]
        self.flag = int(fields[1])
        self.rname = fields[2]
        self.mapq = int(fields[4])
        self.line = line

    @property
    def is_primary(self):
        return not (self.flag & (FLAG_SECONDARY | FLAG_SUPPLEMENTARY))

    @property
    def is_mapped(self):
        return not (self.flag & FLAG_UNMAPPED)

    @property
    def is_read1(self):
        return bool(self.flag & FLAG_READ1)


def validate_header(header_lines, prefix):
    """Calibrator @SQ lines must all follow the host block."""
    seen_calibrator = False
    for line in header_lines:
        if not line.startswith("@SQ\t"):
            continue
        name = ""
        for field in line.rstrip("\n").split("\t"):
            if field.startswith("SN:"):
                name = field[3:]
        if name.startswith(prefix):
            seen_calibrator = True
        elif seen_calibrator:
            raise ValueError(
                f"calibrator contig appears inside the host header block "
                f"before {name!r}; host contigs must come first"
            )


def classify(pair, prefix):
    """Return the pair class using FLAG before RNAME."""
    mapped = [record.is_mapped for record in pair]
    if not any(mapped):
        return "unmapped"
    if sum(mapped) == 1:
        return "singleton"
    origins = {"calib" if record.rname.startswith(prefix) else "host"
               for record in pair}
    if origins == {"host"}:
        return "both_host"
    if origins == {"calib"}:
        return "both_calib"
    return "mixed"


def check_pair(pair, qname):
    if len(pair) > 2:
        raise ValueError(f"{qname}: more than two primary records in one group")
    # Diagnose the absent mate specifically before reporting the group size.
    if not any(record.is_read1 for record in pair):
        raise ValueError(
            f"{qname}: missing read1 (FLAG 0x40). A record-level MAPQ filter "
            f"(samtools view -q) orphans mates; classify the unfiltered "
            f"alignment and let this step apply the threshold per pair.")
    if all(record.is_read1 for record in pair):
        raise ValueError(f"{qname}: missing read2, both primary records set FLAG 0x40")
    if len(pair) < 2:
        raise ValueError(f"{qname}: incomplete pair, only {len(pair)} primary record(s)")
    # Each record's own 0x4 must agree with its mate's 0x8.
    first, second = pair
    for record, mate in ((first, second), (second, first)):
        mate_says_unmapped = bool(record.flag & FLAG_MATE_UNMAPPED)
        if mate_says_unmapped != (not mate.is_mapped):
            raise ValueError(
                f"{qname}: contradictory mate flags between 0x4 and 0x8")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sample-id", required=True)
    parser.add_argument("--mapq", type=int, required=True)
    parser.add_argument("--calib-prefix", default="calib__")
    parser.add_argument("--host-sam", required=True)
    parser.add_argument("--counts", required=True)
    parser.add_argument("--summary", required=True)
    args = parser.parse_args(argv)

    prefix = args.calib_prefix
    thresholds = sorted({0, args.mapq, 30})

    class_totals = {name: 0 for name in CLASSES}
    # strata[(pair_class, proper, threshold, dup_state)] = fragments
    strata = {}
    read1_primaries = 0

    header_lines = []
    seen_groups = set()

    host = open(args.host_sam, "w")
    try:
        current_name = None
        pair = []

        def flush():
            nonlocal pair, read1_primaries
            if not pair:
                return
            qname = pair[0].qname
            check_pair(pair, qname)
            read1_primaries += sum(1 for record in pair if record.is_read1)

            pair_class = classify(pair, prefix)
            class_totals[pair_class] += 1

            if pair_class in ("both_host", "both_calib"):
                proper = "true" if all(record.flag & FLAG_PROPER for record in pair) else "false"
                duplicated = any(record.flag & FLAG_DUPLICATE for record in pair)
                for threshold in thresholds:
                    # A pair passes only when both primary mates meet the cut.
                    if min(record.mapq for record in pair) < threshold:
                        continue
                    for state in DUPLICATE_STATES:
                        if state == "nonduplicate" and duplicated:
                            continue
                        key = (pair_class, proper, threshold, state)
                        strata[key] = strata.get(key, 0) + 1

            if pair_class == "both_host":
                for record in pair:
                    host.write(record.line)
            pair = []

        for line in sys.stdin:
            if line.startswith("@"):
                header_lines.append(line)
                continue
            if header_lines and not host.tell():
                validate_header(header_lines, prefix)
                host.writelines(header_lines)

            record = Record(line)
            if not record.is_primary:
                continue
            if record.qname != current_name:
                flush()
                if record.qname in seen_groups:
                    raise ValueError(
                        f"{record.qname}: input is not name-collated; "
                        f"this query name was already closed")
                seen_groups.add(record.qname)
                current_name = record.qname
            pair.append(record)
        flush()

        if header_lines and not host.tell():
            validate_header(header_lines, prefix)
            host.writelines(header_lines)
    finally:
        host.close()

    # Reconcile: every fragment is counted once, via its read1 primary record.
    total_classified = sum(class_totals.values())
    if total_classified != read1_primaries:
        raise ValueError(
            f"pair-class totals ({total_classified}) do not reconcile with "
            f"primary read1 records ({read1_primaries})")

    with open(args.counts, "w") as out:
        out.write("SampleID\tpair_class\tproper_pair\tmapq_threshold\t"
                  "duplicate_state\tfragment_count\n")
        for name in CLASSES:
            out.write(f"{args.sample_id}\t{name}\tNA\tNA\tall\t{class_totals[name]}\n")
        for pair_class in ("both_host", "both_calib"):
            for proper in ("true", "false"):
                for threshold in thresholds:
                    for state in DUPLICATE_STATES:
                        count = strata.get((pair_class, proper, threshold, state), 0)
                        out.write(f"{args.sample_id}\t{pair_class}\t{proper}\t"
                                  f"{threshold}\t{state}\t{count}\n")

    with open(args.summary, "w") as out:
        out.write("SampleID\thost_fragments\texternal_fragments\t"
                  "classified_fragments\texternal_fraction\tmapq_threshold\t"
                  "duplicate_state\n")
        for threshold in thresholds:
            for state in DUPLICATE_STATES:
                host_fragments = strata.get(("both_host", "true", threshold, state), 0)
                external_fragments = strata.get(("both_calib", "true", threshold, state), 0)
                classified = host_fragments + external_fragments
                external_fraction = (external_fragments / classified
                                     if classified else float("nan"))
                out.write(f"{args.sample_id}\t{host_fragments}\t{external_fragments}\t"
                          f"{classified}\t{external_fraction}\t{threshold}\t{state}\n")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print(f"{type(error).__name__}: {error}", file=sys.stderr)
        sys.exit(1)
