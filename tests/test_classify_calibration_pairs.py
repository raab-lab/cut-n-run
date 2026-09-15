"""Unit tests for competitive-alignment pair classification.

The classification contract these protect:

* mapping status comes from FLAG 0x4, never from RNAME, because an unmapped
  mate carries its mapped partner's RNAME and POS;
* ``mixed`` is measured at the pair level, before FLAG 0x2 is consulted, so it
  is not structurally zero;
* only ``both_host`` pairs reach the host SAM.
"""

import csv
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO = pathlib.Path(__file__).resolve().parent.parent
CLASSIFIER = REPO / "bin" / "classify_calibration_pairs.py"
FIXTURE = REPO / "tests" / "fixtures" / "classification.sam"


def read_tsv(path):
    with open(path, newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


class ClassifyPairsTests(unittest.TestCase):

    def setUp(self):
        self.tmp = pathlib.Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)

    def run_classifier(self, sam_text, mapq="10", sample_id="fixture", check=True):
        host_sam = self.tmp / "host.sam"
        counts = self.tmp / "counts.tsv"
        summary = self.tmp / "summary.tsv"
        result = subprocess.run(
            [sys.executable, str(CLASSIFIER),
             "--sample-id", sample_id, "--mapq", mapq, "--calib-prefix", "calib__",
             "--host-sam", str(host_sam), "--counts", str(counts),
             "--summary", str(summary)],
            input=sam_text, capture_output=True, text=True, check=check,
        )
        return result, host_sam, counts, summary

    def fixture_text(self):
        return FIXTURE.read_text()

    # -- happy path -------------------------------------------------------

    def test_class_totals(self):
        _, _, counts, _ = self.run_classifier(self.fixture_text())
        rows = read_tsv(counts)
        class_totals = {
            row["pair_class"]: int(row["fragment_count"])
            for row in rows
            if row["proper_pair"] == "NA" and row["mapq_threshold"] == "NA"
        }
        self.assertEqual(class_totals, {
            "both_host": 2, "both_calib": 1, "mixed": 1,
            "singleton": 1, "unmapped": 1,
        })

    def test_primary_summary(self):
        _, _, _, summary = self.run_classifier(self.fixture_text())
        rows = read_tsv(summary)
        primary = [r for r in rows
                   if r["mapq_threshold"] == "10" and r["duplicate_state"] == "all"]
        self.assertEqual(len(primary), 1)
        primary_summary = primary[0]
        self.assertEqual(primary_summary["host_fragments"], "2")
        self.assertEqual(primary_summary["external_fragments"], "1")
        self.assertEqual(primary_summary["classified_fragments"], "3")
        self.assertEqual(primary_summary["external_fraction"], "0.3333333333333333")

    def test_host_sam_excludes_calibrator(self):
        _, host_sam, _, _ = self.run_classifier(self.fixture_text())
        records = [l for l in host_sam.read_text().splitlines() if not l.startswith("@")]
        host_sam_records = "\n".join(records)
        self.assertNotIn("calib__", host_sam_records)
        # Both mates of each both_host pair are written; secondary and
        # supplementary records are not.
        self.assertEqual(len(records), 4)
        self.assertEqual({l.split("\t")[0] for l in records},
                         {"host_pair", "duplicate_pair"})

    def test_host_sam_retains_combined_header(self):
        # The reheader step downstream strips the calibrator @SQ lines; this
        # stage must preserve every non-@SQ header record.
        _, host_sam, _, _ = self.run_classifier(self.fixture_text())
        header = [l for l in host_sam.read_text().splitlines() if l.startswith("@")]
        self.assertTrue(any(l.startswith("@RG") for l in header))
        self.assertTrue(any(l.startswith("@PG") for l in header))
        self.assertTrue(any("SN:calib__chrCalib1" in l for l in header))

    def test_duplicate_stratification(self):
        _, _, counts, _ = self.run_classifier(self.fixture_text())
        rows = read_tsv(counts)

        def total(pair_class, proper, mapq, dup):
            return int(next(r["fragment_count"] for r in rows
                            if r["pair_class"] == pair_class
                            and r["proper_pair"] == proper
                            and r["mapq_threshold"] == mapq
                            and r["duplicate_state"] == dup))

        # One of the two both_host pairs carries FLAG 0x400.
        self.assertEqual(total("both_host", "true", "10", "all"), 2)
        self.assertEqual(total("both_host", "true", "10", "nonduplicate"), 1)
        self.assertEqual(total("both_calib", "true", "10", "all"), 1)
        self.assertEqual(total("both_calib", "true", "30", "all"), 1)

    def test_mapq_strata_present(self):
        _, _, counts, _ = self.run_classifier(self.fixture_text())
        thresholds = {r["mapq_threshold"] for r in read_tsv(counts)}
        self.assertEqual(thresholds, {"NA", "0", "10", "30"})

    def test_unmapped_mate_rname_does_not_make_a_host_pair(self):
        # The singleton's unmapped record carries chrHost2 at the mate's POS.
        # Classifying on RNAME would call this both_host.
        _, _, counts, _ = self.run_classifier(self.fixture_text())
        rows = read_tsv(counts)
        singleton = next(int(r["fragment_count"]) for r in rows
                         if r["pair_class"] == "singleton"
                         and r["proper_pair"] == "NA")
        self.assertEqual(singleton, 1)

    # -- rejections -------------------------------------------------------

    def header(self):
        return "\n".join(l for l in self.fixture_text().splitlines()
                         if l.startswith("@"))

    def test_missing_read1_is_rejected(self):
        sam = self.header() + "\n" + "\t".join(
            ["orphan", "147", "chrHost1", "300", "42", "10M", "=", "100", "-210",
             "ACGTACGTAC", "IIIIIIIIII"]) + "\n"
        result, *_ = self.run_classifier(sam, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertRegex(result.stderr, "missing read1")

    def test_more_than_two_primary_records_is_rejected(self):
        line = "\t".join(["triple", "99", "chrHost1", "100", "42", "10M", "=",
                          "300", "210", "ACGTACGTAC", "IIIIIIIIII"])
        mate = "\t".join(["triple", "147", "chrHost1", "300", "42", "10M", "=",
                          "100", "-210", "ACGTACGTAC", "IIIIIIIIII"])
        sam = self.header() + "\n" + line + "\n" + mate + "\n" + line + "\n"
        result, *_ = self.run_classifier(sam, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertRegex(result.stderr, "more than two primary records")

    def test_contradictory_mate_flags_are_rejected(self):
        # read1 says its mate is unmapped (0x8) while read2 is mapped.
        r1 = "\t".join(["bad", "73", "chrHost1", "100", "42", "10M", "=", "300",
                        "210", "ACGTACGTAC", "IIIIIIIIII"])
        r2 = "\t".join(["bad", "147", "chrHost1", "300", "42", "10M", "=", "100",
                        "-210", "ACGTACGTAC", "IIIIIIIIII"])
        sam = self.header() + "\n" + r1 + "\n" + r2 + "\n"
        result, *_ = self.run_classifier(sam, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertRegex(result.stderr, "contradictory mate flags")

    def test_calibrator_contig_inside_host_header_block_is_rejected(self):
        # Host contig order is what keeps reference IDs valid when the trailing
        # calibrator @SQ lines are stripped, so interleaving is fatal.
        header = [
            "@HD\tVN:1.6\tSO:queryname",
            "@SQ\tSN:chrHost1\tLN:2000",
            "@SQ\tSN:calib__chrCalib1\tLN:1200",
            "@SQ\tSN:chrHost2\tLN:1500",
        ]
        sam = "\n".join(header) + "\n"
        result, *_ = self.run_classifier(sam, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertRegex(result.stderr, "host header block")

    def test_uncollated_input_is_rejected(self):
        a1 = "\t".join(["a", "99", "chrHost1", "100", "42", "10M", "=", "300",
                        "210", "ACGTACGTAC", "IIIIIIIIII"])
        a2 = "\t".join(["a", "147", "chrHost1", "300", "42", "10M", "=", "100",
                        "-210", "ACGTACGTAC", "IIIIIIIIII"])
        b1 = "\t".join(["b", "99", "chrHost1", "100", "42", "10M", "=", "300",
                        "210", "ACGTACGTAC", "IIIIIIIIII"])
        b2 = "\t".join(["b", "147", "chrHost1", "300", "42", "10M", "=", "100",
                        "-210", "ACGTACGTAC", "IIIIIIIIII"])
        sam = self.header() + "\n" + "\n".join([a1, a2, b1, b2, a1, a2]) + "\n"
        result, *_ = self.run_classifier(sam, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertRegex(result.stderr, "not name-collated")


if __name__ == "__main__":
    unittest.main()
