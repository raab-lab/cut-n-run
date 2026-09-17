"""Tests for exact-match barcode spike-in counting.

Barcoded nucleosome panels share a Widom 601 backbone, so these are counted by
sequence match rather than alignment. The properties that matter: a fragment is
counted once, either mate may carry the barcode, either orientation matches,
and disagreeing mates are excluded rather than double counted.
"""

import gzip
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "bin"))
import count_barcodes as cb  # noqa: E402

# Synthetic panel. The real K-MetStat sequences come from the vendor.
PANEL = {"K4me3": "TTCGCGGGAATTCAA", "K27me3": "GGATCCTAAGCCTAT", "K9me3": "CCAATTGGCCTTAAC"}


def write_fasta(path, panel):
    path.write_text("".join(f">{n}\n{s}\n" for n, s in panel.items()))


def write_fastq(path, seqs, gz=False):
    text = "".join(f"@r{i}\n{s}\n+\n{'I'*len(s)}\n" for i, s in enumerate(seqs))
    if gz:
        with gzip.open(path, "wt") as fh:
            fh.write(text)
    else:
        path.write_text(text)


FILLER = "ACGTACGTACGTACGTACGTACGTACGT"


class CountBarcodesTests(unittest.TestCase):

    def setUp(self):
        self.tmp = pathlib.Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.fa = self.tmp / "panel.fa"
        write_fasta(self.fa, PANEL)

    def run_count(self, r1_seqs, r2_seqs):
        r1, r2 = self.tmp / "r1.fastq", self.tmp / "r2.fastq"
        write_fastq(r1, r1_seqs)
        write_fastq(r2, r2_seqs)
        return cb.count_barcodes(r1, r2, PANEL)

    def test_barcode_on_read1_is_counted_once(self):
        res = self.run_count([FILLER + PANEL["K4me3"] + FILLER], [FILLER * 2])
        self.assertEqual(res["barcode_fragments"], 1)
        self.assertEqual(res["per_barcode"]["K4me3"], 1)

    def test_barcode_on_read2_is_counted(self):
        res = self.run_count([FILLER * 2], [FILLER + PANEL["K27me3"] + FILLER])
        self.assertEqual(res["per_barcode"]["K27me3"], 1)

    def test_barcode_on_both_mates_counts_one_fragment(self):
        bc = PANEL["K4me3"]
        res = self.run_count([FILLER + bc], [bc + FILLER])
        self.assertEqual(res["barcode_fragments"], 1)
        self.assertEqual(res["per_barcode"]["K4me3"], 1)

    def test_reverse_complement_is_matched(self):
        rc = cb.revcomp(PANEL["K9me3"])
        res = self.run_count([FILLER + rc + FILLER], [FILLER * 2])
        self.assertEqual(res["per_barcode"]["K9me3"], 1)

    def test_disagreeing_mates_are_excluded(self):
        res = self.run_count([FILLER + PANEL["K4me3"]], [FILLER + PANEL["K27me3"]])
        self.assertEqual(res["barcode_fragments"], 0)
        self.assertEqual(res["ambiguous_fragments"], 1)

    def test_two_panel_members_in_one_read_are_ambiguous(self):
        res = self.run_count([PANEL["K4me3"] + FILLER + PANEL["K9me3"]], [FILLER])
        self.assertEqual(res["barcode_fragments"], 0)
        self.assertEqual(res["ambiguous_fragments"], 1)

    def test_unbarcoded_fragments_count_toward_total_only(self):
        res = self.run_count([FILLER] * 5, [FILLER] * 5)
        self.assertEqual(res["total_fragments"], 5)
        self.assertEqual(res["barcode_fragments"], 0)

    def test_mixed_library_totals(self):
        r1 = [FILLER + PANEL["K4me3"], FILLER, FILLER + PANEL["K27me3"], FILLER]
        r2 = [FILLER, FILLER, FILLER, FILLER]
        res = self.run_count(r1, r2)
        self.assertEqual(res["total_fragments"], 4)
        self.assertEqual(res["barcode_fragments"], 2)
        self.assertEqual(res["per_barcode"]["K4me3"], 1)
        self.assertEqual(res["per_barcode"]["K27me3"], 1)
        self.assertEqual(res["per_barcode"]["K9me3"], 0)

    def test_gzipped_input_is_supported(self):
        r1, r2 = self.tmp / "r1.fastq.gz", self.tmp / "r2.fastq.gz"
        write_fastq(r1, [FILLER + PANEL["K4me3"]], gz=True)
        write_fastq(r2, [FILLER], gz=True)
        res = cb.count_barcodes(r1, r2, PANEL)
        self.assertEqual(res["per_barcode"]["K4me3"], 1)

    def test_empty_panel_is_rejected(self):
        empty = self.tmp / "empty.fa"
        empty.write_text("")
        with self.assertRaisesRegex(ValueError, "no barcode sequences"):
            cb.read_fasta(empty)

    def test_barcode_without_sequence_is_rejected(self):
        bad = self.tmp / "bad.fa"
        bad.write_text(">K4me3\n>K27me3\nACGT\n")
        with self.assertRaisesRegex(ValueError, "no sequence"):
            cb.read_fasta(bad)

    def test_cli_writes_both_tables(self):
        r1, r2 = self.tmp / "a_1.fastq", self.tmp / "a_2.fastq"
        write_fastq(r1, [FILLER + PANEL["K4me3"], FILLER])
        write_fastq(r2, [FILLER, FILLER])
        counts, summary = self.tmp / "c.tsv", self.tmp / "s.tsv"
        rc = subprocess.run(
            [sys.executable, str(REPO / "bin" / "count_barcodes.py"),
             "--sample-id", "S1", "--barcodes", str(self.fa),
             "--r1", str(r1), "--r2", str(r2),
             "--counts", str(counts), "--summary", str(summary)], check=True)
        self.assertEqual(rc.returncode, 0)
        rows = [l.split("\t") for l in counts.read_text().splitlines()[1:]]
        self.assertEqual(len(rows), 3)  # one row per panel member, including zeros
        head, data = summary.read_text().splitlines()
        self.assertIn("barcode_fraction", head)
        fields = data.split("\t")
        self.assertEqual(fields[0], "S1")
        self.assertEqual(fields[1], "2")   # total fragments
        self.assertEqual(fields[2], "1")   # barcode fragments
        self.assertAlmostEqual(float(fields[4]), 0.5)


if __name__ == "__main__":
    unittest.main()


class BarcodeCalibrationSummaryTests(unittest.TestCase):
    """The barcode path must emit the same summary schema as the competitive path."""

    BUILDER = REPO / "bin" / "build_barcode_calibration_summary.py"
    CLASSIFIER = REPO / "bin" / "classify_calibration_pairs.py"
    FIXTURE = REPO / "tests" / "fixtures" / "classification.sam"

    def setUp(self):
        self.tmp = pathlib.Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)

    def host_counts(self):
        """Run the real classifier with a prefix that cannot match any contig."""
        counts = self.tmp / "host_counts.tsv"
        subprocess.run(
            [sys.executable, str(self.CLASSIFIER), "--sample-id", "S1",
             "--mapq", "10", "--calib-prefix", "__no_calibrator_contig__",
             "--host-sam", str(self.tmp / "host.sam"),
             "--counts", str(counts), "--summary", str(self.tmp / "hs.tsv")],
            input=self.FIXTURE.read_text(), capture_output=True, text=True, check=True)
        return counts

    def panel(self):
        path = self.tmp / "panel.fa"
        path.write_text(
            ">K4me3_A target=H3K4me3\nAAAA\n>K4me3_B target=H3K4me3\nCCCC\n"
            ">K27me3_A target=H3K27me3\nGGGG\n>K9me3_A target=H3K9me3\nTTTT\n")
        return path

    def barcode_summary(self, on_target=250, off_target=750):
        """Per-barcode counts: on-target split across A/B, plus off-target."""
        path = self.tmp / "barcode_counts.tsv"
        rows = [("K4me3_A", on_target // 2), ("K4me3_B", on_target - on_target // 2),
                ("K27me3_A", off_target // 2), ("K9me3_A", off_target - off_target // 2)]
        path.write_text("SampleID\tbarcode\tfragment_count\n" +
                        "".join(f"S1\t{n}\t{v}\n" for n, v in rows))
        return path

    def build(self, barcode, host, check=True, target="H3K4me3"):
        out = self.tmp / "calibration_summary.tsv"
        res = subprocess.run(
            [sys.executable, str(self.BUILDER), "--sample-id", "S1",
             "--barcode-counts", str(barcode), "--barcodes", str(self.panel()),
             "--target", target, "--host-counts", str(host),
             "--summary", str(out)], capture_output=True, text=True, check=check)
        return res, out

    def test_external_count_uses_the_on_target_barcode_only(self):
        # Off-target members measure cross-reactivity, not spiked material.
        _, out = self.build(self.barcode_summary(on_target=250, off_target=750),
                            self.host_counts())
        rows = [l.split("\t") for l in out.read_text().splitlines()[1:]]
        self.assertEqual({r[2] for r in rows}, {"250"})
        self.assertEqual({r[7] for r in rows}, {"on_target:H3K4me3"})
        self.assertEqual({r[8] for r in rows}, {"1000"})  # total panel retained as QC

    def test_background_corrected_count_subtracts_the_median_off_target(self):
        # Panel: on-target H3K4me3 = 250 (A+B); off-target PTMs = 375 and 375.
        _, out = self.build(self.barcode_summary(on_target=250, off_target=750),
                            self.host_counts())
        rows = [l.split("\t") for l in out.read_text().splitlines()[1:]]
        # Two off-target PTMs at 375 each -> median 375 -> 250 - 375 = -125.
        self.assertEqual({r[10] for r in rows}, {"-125"})
        self.assertEqual({r[11] for r in rows}, {"375"})

    def test_background_correction_is_positive_with_real_enrichment(self):
        _, out = self.build(self.barcode_summary(on_target=4000, off_target=400),
                            self.host_counts())
        rows = [l.split("\t") for l in out.read_text().splitlines()[1:]]
        # Off-target PTMs at 200 each -> median 200 -> 4000 - 200 = 3800.
        self.assertEqual({r[10] for r in rows}, {"3800"})
        # The uncorrected on-target count is unchanged, so the default stands.
        self.assertEqual({r[2] for r in rows}, {"4000"})

    def test_absent_target_falls_back_to_the_whole_panel_and_says_so(self):
        # An IgG control has no on-target member.
        res, out = self.build(self.barcode_summary(), self.host_counts(), target="IgG")
        rows = [l.split("\t") for l in out.read_text().splitlines()[1:]]
        self.assertEqual({r[2] for r in rows}, {"1000"})
        self.assertEqual({r[7] for r in rows}, {"all_barcodes"})
        self.assertRegex(res.stderr, "no on-target barcode")

    def test_schema_matches_the_competitive_path(self):
        _, out = self.build(self.barcode_summary(), self.host_counts())
        header = out.read_text().splitlines()[0].split("\t")
        # The seven contract columns the importer requires come first; the
        # barcode path appends provenance after them.
        self.assertEqual(header[:7], ["SampleID", "host_fragments", "external_fragments",
                                      "classified_fragments", "external_fraction",
                                      "mapq_threshold", "duplicate_state"])
        self.assertEqual(header[7:], ["calibration_basis", "total_barcode_fragments",
                                      "on_target_fraction",
                                      "external_count_bg_corrected",
                                      "off_target_median"])

    def test_every_calibrator_pair_class_is_empty_with_no_match_prefix(self):
        # All fixture pairs must land in both_host, so the host count is honest.
        counts = self.host_counts()
        rows = [l.split("\t") for l in counts.read_text().splitlines()[1:]]
        calib = [r for r in rows if r[1] == "both_calib" and r[5] != "0"]
        self.assertEqual(calib, [])

    def test_external_count_is_constant_across_mapq_strata(self):
        # Barcodes are counted pre-alignment, so they carry no MAPQ.
        _, out = self.build(self.barcode_summary(on_target=250), self.host_counts())
        rows = [l.split("\t") for l in out.read_text().splitlines()[1:]]
        self.assertTrue(rows)
        self.assertEqual({r[2] for r in rows}, {"250"})
        self.assertEqual({r[6] for r in rows}, {"all"})
        # Host counts may still differ between thresholds.
        self.assertGreaterEqual(len({r[5] for r in rows}), 2)

    def test_fraction_is_external_over_classified(self):
        _, out = self.build(self.barcode_summary(on_target=100), self.host_counts())
        for line in out.read_text().splitlines()[1:]:
            _, host, ext, classified, frac = line.split("\t")[:5]
            self.assertEqual(int(classified), int(host) + int(ext))
            self.assertAlmostEqual(float(frac), int(ext) / int(classified))

    def test_zero_barcode_fragments_is_an_error(self):
        # Silently emitting a zero external count would produce a meaningless
        # size factor rather than a failure.
        res, _ = self.build(self.barcode_summary(on_target=0, off_target=0),
                            self.host_counts(), check=False)
        self.assertNotEqual(res.returncode, 0)
        self.assertRegex(res.stderr, "no barcode fragments")
