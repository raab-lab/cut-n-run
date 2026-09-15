"""Source-level regression tests for the calibration branch invariants.

These guard properties that are cheap to break with an ordinary edit and
expensive to notice afterwards, because the symptom is a silently wrong
normalization factor rather than a crash:

* Bowtie2 must keep its default mixed and discordant search modes, or the
  ``mixed`` and ``singleton`` pair classes become structurally zero.
* Duplicates must be marked once, on the combined BAM, before partitioning, so
  host and calibrator fragments carry the same duplicate policy.
* The calibration branch must never re-run the host-only MarkDuplicates step.
"""

import pathlib
import re
import unittest

REPO = pathlib.Path(__file__).resolve().parent.parent

ALIGN = (REPO / "modules" / "align.nf").read_text()
REFERENCE = (REPO / "modules" / "reference.nf").read_text()
QC = (REPO / "modules" / "qc.nf").read_text()
MULTIQC = (REPO / "modules" / "multiqc.nf").read_text()
CORE = (REPO / "subworkflows" / "cnr.nf").read_text()

FORBIDDEN = ("--no-mixed", "--no-discordant")


def calibration_branch(source):
    """Return the text of the calibration branch of the CNR workflow."""
    match = re.search(r"if\s*\(\s*params\.external_calibration_fasta\s*\)\s*\{",
                      source)
    if match is None:
        raise AssertionError("no calibration branch found in subworkflows/cnr.nf")
    start = match.end()
    depth = 1
    for index in range(start, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[start:index]
    raise AssertionError("unbalanced braces in calibration branch")


def resolved_bowtie2_args(source, mode):
    """Reproduce the argument string the alignment process would resolve."""
    preset = "--very-sensitive-local" if mode == "local" else "--very-sensitive"
    match = re.search(r'def args\s*=\s*"([^"]+)"', source)
    if match is None:
        raise AssertionError("bt2_combined does not build an explicit args string")
    return match.group(1).replace("${preset}", preset)


class CalibrationContractTests(unittest.TestCase):

    def test_both_alignment_presets_are_available(self):
        self.assertIn("--very-sensitive-local", ALIGN)
        self.assertIn("--very-sensitive", ALIGN)

    def test_resolved_args_never_suppress_mixed_or_discordant(self):
        for mode in ("local", "end-to-end"):
            resolved = resolved_bowtie2_args(ALIGN, mode)
            for option in FORBIDDEN:
                self.assertNotIn(
                    option, resolved,
                    msg=(f"calibration mode {mode!r} resolved Bowtie2 arguments "
                         f"{resolved!r}, which contain {option}; suppressing "
                         f"mixed/discordant output makes the singleton and "
                         f"mixed pair classes structurally zero"),
                )

    def test_alignment_validates_forbidden_options_at_runtime(self):
        # A future extra-argument interface must still be rejected.
        self.assertIn("--no-mixed", ALIGN)
        self.assertIn("--no-discordant", ALIGN)
        self.assertIn("error", ALIGN)

    def test_reference_fastas_are_staged_without_collision(self):
        # hg38_UCSC and dm6_UCSC both ship
        # Sequence/WholeGenomeFasta/genome.fa, so staging both into one work
        # directory fails with an input file name collision.
        self.assertIn("stageAs: 'host/*'", REFERENCE)
        self.assertIn("stageAs: 'external/*'", REFERENCE)

    def test_duplicates_are_marked_before_partitioning(self):
        self.assertIn("picard_md_combined", CORE)
        self.assertIn("partition_calibration_bam", CORE)
        self.assertLess(CORE.index("picard_md_combined"),
                        CORE.index("partition_calibration_bam"))

    def test_calibration_branch_never_reruns_host_markduplicates(self):
        branch = calibration_branch(CORE)
        self.assertEqual(branch.count("picard_md("), 0,
                         msg="calibration branch must not re-run host MarkDuplicates")

    def test_coverage_consumes_the_host_marked_bam(self):
        # One shared coverage call consumes host_marked_bam. Invoking
        # single_coverage inside each branch would require a second alias and
        # duplicate the analysis workflow, so the invariant is that the
        # calibration branch defines host_marked_bam and coverage reads it.
        branch = calibration_branch(CORE)
        self.assertIn("host_marked_bam =", branch)
        self.assertIn("single_coverage(host_marked_bam", CORE)

    def test_combined_duplicate_metrics_reach_multiqc(self):
        self.assertIn("combined_dup_metrics", MULTIQC)

    def test_combined_markduplicates_keeps_duplicates(self):
        self.assertIn("picard_md_combined", QC)
        self.assertIn("REMOVE_DUPLICATES=false", QC)

    def test_host_genome_size_is_used_downstream(self):
        # MACS2 and bamCoverage must receive the host effective genome size,
        # never the combined reference length.
        branch = calibration_branch(CORE)
        self.assertIn("params.genomeSize", branch)
        self.assertNotIn("combined_genome_size", branch)

    def test_filter_call_site_documents_the_count_boundary(self):
        branch = calibration_branch(CORE)
        self.assertIn("calibration_summary.tsv", branch,
                      msg="the calibration filter call site must state that "
                          "pair-level counts cannot be rebuilt from the BAM")


if __name__ == "__main__":
    unittest.main()
