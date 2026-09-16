"""Unit tests for combined host/calibrator reference construction and caching.

These use a fake ``bowtie2-build`` so the cache-key, validation, and atomic
publication logic can be exercised without a real index build.
"""

import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import textwrap
import time
import unittest

REPO = pathlib.Path(__file__).resolve().parent.parent
BUILDER = REPO / "bin" / "build_combined_reference.py"
sys.path.insert(0, str(REPO / "bin"))

HOST = REPO / "tests" / "fixtures" / "host.fa"
CALIB = REPO / "tests" / "fixtures" / "calibrator.fa"

FAKE_BOWTIE2_BUILD = textwrap.dedent(
    """\
    #!/usr/bin/env bash
    # Minimal bowtie2-build stand-in: emits the six expected index files.
    set -euo pipefail
    if [[ "${1:-}" == "--version" ]]; then
        echo "bowtie2-build-s version 2.5.4"
        exit 0
    fi
    out="${@: -1}"
    for suffix in 1 2 3 4; do
        : > "${out}.${suffix}.bt2"
    done
    : > "${out}.rev.1.bt2"
    : > "${out}.rev.2.bt2"
    """
)


def make_fake_bowtie2(directory):
    """Install a fake bowtie2-build into *directory* and return a PATH for it."""
    directory = pathlib.Path(directory)
    exe = directory / "bowtie2-build"
    exe.write_text(FAKE_BOWTIE2_BUILD)
    exe.chmod(0o755)
    return f"{directory}{os.pathsep}{os.environ['PATH']}"


def run_builder(env_path, extra, check=True):
    """Invoke the builder as a subprocess and return the CompletedProcess."""
    env = dict(os.environ, PATH=env_path)
    return subprocess.run(
        [sys.executable, str(BUILDER), "--host", str(HOST), "--external", str(CALIB)] + extra,
        capture_output=True, text=True, env=env, check=check,
    )


class CombinedReferenceTests(unittest.TestCase):

    def setUp(self):
        self.tmp = pathlib.Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        fake_bin = self.tmp / "bin"
        fake_bin.mkdir(parents=True)
        self.path = make_fake_bowtie2(fake_bin)

    # -- contig naming ----------------------------------------------------

    def test_host_contigs_unchanged_and_external_prefixed(self):
        out = self.tmp / "out"
        run_builder(self.path, ["--output-dir", str(out)])
        manifest = json.loads((out / "reference_manifest.json").read_text())
        host_names = [c["name"] for c in manifest["contigs"] if c["origin"] == "host"]
        external_names = [c["name"] for c in manifest["contigs"] if c["origin"] == "external"]
        self.assertEqual(host_names, ["chrHost1", "chrHost2"])
        self.assertEqual(external_names, ["calib__chrCalib1"])

    def test_host_contigs_are_written_first(self):
        out = self.tmp / "order"
        run_builder(self.path, ["--output-dir", str(out)])
        names = [
            line[1:].split()[0]
            for line in (out / "combined.fa").read_text().splitlines()
            if line.startswith(">")
        ]
        self.assertEqual(names, ["chrHost1", "chrHost2", "calib__chrCalib1"])

    # -- cache key --------------------------------------------------------

    def test_identical_content_yields_identical_key(self):
        cache = self.tmp / "cache"
        first = run_builder(self.path, ["--cache-dir", str(cache)]).stdout.strip()
        second = run_builder(self.path, ["--cache-dir", str(cache)]).stdout.strip()
        self.assertEqual(first, second)
        self.assertEqual(pathlib.Path(first).name, pathlib.Path(second).name)

    def test_changed_fasta_yields_different_key(self):
        cache = self.tmp / "cache2"
        first_key = pathlib.Path(run_builder(self.path, ["--cache-dir", str(cache)]).stdout.strip()).name
        changed = self.tmp / "calibrator_changed.fa"
        changed.write_text(CALIB.read_text().replace("ACGT", "TGCA", 1))
        env = dict(os.environ, PATH=self.path)
        result = subprocess.run(
            [sys.executable, str(BUILDER), "--host", str(HOST), "--external", str(changed),
             "--cache-dir", str(cache)],
            capture_output=True, text=True, env=env, check=True,
        )
        self.assertNotEqual(first_key, pathlib.Path(result.stdout.strip()).name)

    # -- input rejection --------------------------------------------------

    def test_host_using_reserved_prefix_is_rejected(self):
        bad = self.tmp / "bad_host.fa"
        bad.write_text(">calib__chrHost1\nACGT\n")
        env = dict(os.environ, PATH=self.path)
        result = subprocess.run(
            [sys.executable, str(BUILDER), "--host", str(bad), "--external", str(CALIB),
             "--output-dir", str(self.tmp / "nope")],
            capture_output=True, text=True, env=env,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertRegex(result.stderr, "reserved prefix")

    def test_duplicate_contig_is_rejected(self):
        dup = self.tmp / "dup.fa"
        dup.write_text(">chrDup\nACGT\n>chrDup\nTTTT\n")
        env = dict(os.environ, PATH=self.path)
        result = subprocess.run(
            [sys.executable, str(BUILDER), "--host", str(dup), "--external", str(CALIB),
             "--output-dir", str(self.tmp / "nope2")],
            capture_output=True, text=True, env=env,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertRegex(result.stderr, "duplicate contig")

    def test_blank_contig_name_is_rejected(self):
        blank = self.tmp / "blank.fa"
        blank.write_text(">\nACGT\n")
        env = dict(os.environ, PATH=self.path)
        result = subprocess.run(
            [sys.executable, str(BUILDER), "--host", str(blank), "--external", str(CALIB),
             "--output-dir", str(self.tmp / "nope3")],
            capture_output=True, text=True, env=env,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertRegex(result.stderr, "blank contig name")

    # -- index completeness ----------------------------------------------

    def test_incomplete_index_is_not_reused(self):
        cache = self.tmp / "cache3"
        final = pathlib.Path(run_builder(self.path, ["--cache-dir", str(cache)]).stdout.strip())
        (final / "genome.rev.2.bt2").unlink()
        # A partial entry must be rebuilt rather than silently reused.
        again = pathlib.Path(run_builder(self.path, ["--cache-dir", str(cache)]).stdout.strip())
        self.assertEqual(again, final)
        self.assertTrue((final / "genome.rev.2.bt2").exists())

    def test_mixed_bt2_and_bt2l_is_rejected(self):
        cache = self.tmp / "cache4"
        final = pathlib.Path(run_builder(self.path, ["--cache-dir", str(cache)]).stdout.strip())
        (final / "genome.1.bt2").rename(final / "genome.1.bt2l")
        result = run_builder(self.path, ["--cache-dir", str(cache)], check=False)
        # The mixed entry is invalid, so it is rebuilt; it must never validate as-is.
        self.assertEqual(result.returncode, 0)
        suffixes = {p.suffix for p in final.glob("genome.*")}
        self.assertNotIn(".bt2l", suffixes)

    # -- abandoned build cleanup ------------------------------------------

    def test_stale_temp_dir_is_reclaimed(self):
        import build_combined_reference as builder
        cache = self.tmp / "cache_sweep"
        final = pathlib.Path(run_builder(self.path, ["--cache-dir", str(cache)]).stdout.strip())
        key = final.name

        # A build killed by a signal leaves a multi-GB partial directory behind.
        stale = cache / f".tmp.{key}.deadbeef"
        stale.mkdir()
        (stale / "genome.1.bt2.tmp").write_text("partial")
        old = time.time() - 48 * 3600
        os.utime(stale, (old, old))

        removed = builder.sweep_stale_temp_dirs(cache, key)
        self.assertEqual(removed, [stale])
        self.assertFalse(stale.exists())

    def test_recent_temp_dir_is_left_alone(self):
        # A concurrent build in progress must never be reclaimed.
        import build_combined_reference as builder
        cache = self.tmp / "cache_live"
        final = pathlib.Path(run_builder(self.path, ["--cache-dir", str(cache)]).stdout.strip())
        key = final.name

        live = cache / f".tmp.{key}.livebuild"
        live.mkdir()
        self.assertEqual(builder.sweep_stale_temp_dirs(cache, key), [])
        self.assertTrue(live.exists())

    def test_sweep_leaves_other_keys_untouched(self):
        import build_combined_reference as builder
        cache = self.tmp / "cache_keys"
        cache.mkdir(parents=True)
        other = cache / ".tmp.someotherkey.abc"
        other.mkdir()
        old = time.time() - 48 * 3600
        os.utime(other, (old, old))
        self.assertEqual(builder.sweep_stale_temp_dirs(cache, "thiskey"), [])
        self.assertTrue(other.exists())

    def test_publish_reclaims_stale_dirs(self):
        cache = self.tmp / "cache_publish"
        final = pathlib.Path(run_builder(self.path, ["--cache-dir", str(cache)]).stdout.strip())
        stale = cache / f".tmp.{final.name}.orphan"
        stale.mkdir()
        old = time.time() - 48 * 3600
        os.utime(stale, (old, old))
        result = run_builder(self.path, ["--cache-dir", str(cache)])
        self.assertFalse(stale.exists())
        self.assertIn("removed abandoned build directory", result.stderr)

    # -- concurrency ------------------------------------------------------

    def test_concurrent_builders_resolve_to_one_entry(self):
        cache = self.tmp / "cache5"
        cache.mkdir(parents=True)
        env = dict(os.environ, PATH=self.path)
        cmd = [sys.executable, str(BUILDER), "--host", str(HOST),
               "--external", str(CALIB), "--cache-dir", str(cache)]
        procs = [subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                  text=True, env=env) for _ in range(2)]
        outs = [p.communicate() for p in procs]
        for proc, (_, err) in zip(procs, outs):
            self.assertEqual(proc.returncode, 0, err)

        reported = {out.strip() for out, _ in outs}
        self.assertEqual(len(reported), 1, f"builders disagreed on final path: {reported}")

        entries = sorted(p.name for p in cache.iterdir())
        self.assertEqual(len(entries), 1, f"expected one cache entry, found {entries}")
        self.assertFalse([p for p in cache.iterdir() if p.name.startswith(".tmp.")])


if __name__ == "__main__":
    unittest.main()
