#!/usr/bin/env python3
"""Build and cache a combined host + external-calibrator Bowtie2 reference.

Competitive alignment against one concatenated reference is what lets host
signal and calibration counts be recovered from the same alignment. Host contig
names and their order are preserved so that the host reference IDs stay valid
when the appended calibrator ``@SQ`` lines are stripped from the host BAM later.

Cache entries are content-addressed. A partial build never appears at the final
cache path: builders write to a sibling temporary directory and publish with a
single atomic rename, so concurrent builders converge on one entry.
"""

import argparse
import errno
import hashlib
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import time
import uuid

EXTERNAL_PREFIX = "calib__"
INDEX_SUFFIXES = ("1", "2", "3", "4", "rev.1", "rev.2")
MANIFEST_NAME = "reference_manifest.json"
INDEX_BASENAME = "genome"


# -- FASTA handling ---------------------------------------------------------

def iter_fasta(path):
    """Yield (name, [sequence lines]) streaming, without loading the genome."""
    name = None
    lines = []
    with open(path, "r") as handle:
        for line in handle:
            if line.startswith(">"):
                if name is not None:
                    yield name, lines
                header = line[1:].strip()
                name = header.split()[0] if header.split() else ""
                lines = []
            else:
                lines.append(line)
    if name is not None:
        yield name, lines


def scan_contigs(path, origin, rename):
    """Validate contig names for one FASTA and return their metadata."""
    contigs = []
    seen = set()
    for name, lines in iter_fasta(path):
        if not name:
            raise ValueError(f"blank contig name in {path}")
        if origin == "host" and name.startswith(EXTERNAL_PREFIX):
            raise ValueError(
                f"host contig {name!r} already uses the reserved prefix "
                f"{EXTERNAL_PREFIX!r}"
            )
        if name in seen:
            raise ValueError(f"duplicate contig {name!r} in {path}")
        seen.add(name)
        length = sum(len(line.strip()) for line in lines)
        contigs.append({
            "name": f"{EXTERNAL_PREFIX}{name}" if rename else name,
            "source_name": name,
            "length": length,
            "origin": origin,
        })
    if not contigs:
        raise ValueError(f"no contigs found in {path}")
    return contigs


def write_combined_fasta(host, external, destination):
    """Write host records first, then renamed external records."""
    with open(destination, "w") as out:
        for name, lines in iter_fasta(host):
            out.write(f">{name}\n")
            out.writelines(lines)
        for name, lines in iter_fasta(external):
            out.write(f">{EXTERNAL_PREFIX}{name}\n")
            out.writelines(lines)


# -- cache identity ---------------------------------------------------------

def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def bowtie2_build_version():
    out = subprocess.run(["bowtie2-build", "--version"],
                         capture_output=True, text=True, check=True).stdout
    for token in out.split():
        if token[0].isdigit() and "." in token:
            return token
    raise RuntimeError(f"could not parse bowtie2-build version from: {out!r}")


def compute_cache_key(host_sha256, external_sha256, bowtie2_version):
    # Keyed on the index-format compatibility version, not the patch release,
    # so a patch bump does not force every index to be rebuilt.
    key_material = json.dumps({
        "host_sha256": host_sha256,
        "external_sha256": external_sha256,
        "external_prefix": EXTERNAL_PREFIX,
        "bowtie2_index_compatibility": ".".join(bowtie2_version.split(".")[:2]),
    }, sort_keys=True).encode()
    return hashlib.sha256(key_material).hexdigest()


# -- index validation -------------------------------------------------------

def index_extension(directory):
    """Return 'bt2' or 'bt2l' when a complete, unmixed index set is present."""
    directory = pathlib.Path(directory)
    for extension in ("bt2", "bt2l"):
        present = [
            (directory / f"{INDEX_BASENAME}.{suffix}.{extension}").exists()
            for suffix in INDEX_SUFFIXES
        ]
        if all(present):
            other = "bt2l" if extension == "bt2" else "bt2"
            if any((directory / f"{INDEX_BASENAME}.{suffix}.{other}").exists()
                   for suffix in INDEX_SUFFIXES):
                return None  # mixed sets are never valid
            return extension
    return None


def entry_is_complete(directory, cache_key):
    """A cache entry is reusable only when manifest and index both validate."""
    directory = pathlib.Path(directory)
    manifest_path = directory / MANIFEST_NAME
    if not manifest_path.is_file():
        return False
    if index_extension(directory) is None:
        return False
    try:
        manifest = json.loads(manifest_path.read_text())
    except (OSError, json.JSONDecodeError):
        return False
    return manifest.get("cache_key") == cache_key


# -- build ------------------------------------------------------------------

def build_into(directory, host, external, contigs, manifest):
    directory = pathlib.Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    combined = directory / "combined.fa"
    write_combined_fasta(host, external, combined)

    subprocess.run(
        ["bowtie2-build", "--threads", str(manifest["threads"]),
         str(combined), str(directory / INDEX_BASENAME)],
        check=True, stdout=subprocess.DEVNULL,
    )

    extension = index_extension(directory)
    if extension is None:
        raise RuntimeError(f"bowtie2-build did not produce a complete index in {directory}")

    # The manifest is written only after the index validates, so its presence
    # is what distinguishes a finished entry from an abandoned one.
    manifest = dict(manifest, index_extension=extension, contigs=contigs)
    (directory / MANIFEST_NAME).write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    return directory


# A build killed by a signal (Nextflow aborting the workflow) cannot run its
# own cleanup, so its temporary directory survives holding a partial index.
# Those are never reusable, but they are several GB each, so a later build
# reclaims them. The window is far longer than any real build, which keeps a
# slow concurrent builder's directory safe.
STALE_TEMP_HOURS = 24


def sweep_stale_temp_dirs(cache, cache_key, max_age_hours=STALE_TEMP_HOURS):
    """Remove abandoned temp dirs for this key. Returns the paths removed."""
    cache = pathlib.Path(cache)
    if not cache.is_dir():
        return []
    cutoff = time.time() - max_age_hours * 3600
    removed = []
    for entry in cache.glob(f".tmp.{cache_key}.*"):
        if not entry.is_dir():
            continue
        try:
            if entry.stat().st_mtime >= cutoff:
                continue  # possibly a live build
            shutil.rmtree(entry)
            removed.append(entry)
        except OSError:
            # Another process may be reclaiming it; losing the race is fine.
            continue
    return removed


def publish(cache, cache_key, build):
    """Build into a sibling temp dir and publish with one atomic rename."""
    cache = pathlib.Path(cache)
    cache.mkdir(parents=True, exist_ok=True)
    final_dir = cache / cache_key

    for stale in sweep_stale_temp_dirs(cache, cache_key):
        print(f"removed abandoned build directory {stale}", file=sys.stderr)

    if entry_is_complete(final_dir, cache_key):
        return final_dir

    # Under the cache so the rename stays on one filesystem.
    temp_dir = cache / f".tmp.{cache_key}.{uuid.uuid4().hex}"
    try:
        build(temp_dir)
        try:
            os.rename(temp_dir, final_dir)
        except OSError as error:
            if error.errno not in (errno.EEXIST, errno.ENOTEMPTY):
                raise
            # Another builder won the race. Validate the winner and discard
            # only our own temporary directory; never merge into the final one.
            if not entry_is_complete(final_dir, cache_key):
                raise RuntimeError(
                    f"cache entry {final_dir} exists but is incomplete")
            shutil.rmtree(temp_dir, ignore_errors=True)
    except BaseException:
        shutil.rmtree(temp_dir, ignore_errors=True)
        raise
    return final_dir


def replace_stale_entry(cache, cache_key, build):
    """Rebuild an existing-but-invalid entry without exposing a partial index."""
    cache = pathlib.Path(cache)
    final_dir = cache / cache_key
    temp_dir = cache / f".tmp.{cache_key}.{uuid.uuid4().hex}"
    try:
        build(temp_dir)
        stale = cache / f".stale.{cache_key}.{uuid.uuid4().hex}"
        try:
            os.rename(final_dir, stale)
        except FileNotFoundError:
            stale = None
        os.rename(temp_dir, final_dir)
        if stale is not None:
            shutil.rmtree(stale, ignore_errors=True)
    except BaseException:
        shutil.rmtree(temp_dir, ignore_errors=True)
        raise
    return final_dir


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", required=True, help="host genome FASTA")
    parser.add_argument("--external", required=True, help="external calibrator FASTA")
    parser.add_argument("--cache-dir", default="", help="optional shared cache directory")
    parser.add_argument("--output-dir", default="", help="uncached output directory")
    parser.add_argument("--threads", type=int, default=1)
    args = parser.parse_args(argv)

    if not args.cache_dir and not args.output_dir:
        parser.error("provide --cache-dir or --output-dir")

    host = pathlib.Path(args.host).resolve()
    external = pathlib.Path(args.external).resolve()

    contigs = scan_contigs(host, "host", rename=False)
    contigs += scan_contigs(external, "external", rename=True)

    bowtie2_version = bowtie2_build_version()
    host_sha256 = sha256_file(host)
    external_sha256 = sha256_file(external)
    cache_key = compute_cache_key(host_sha256, external_sha256, bowtie2_version)

    manifest = {
        "cache_key": cache_key,
        "host_fasta": str(host),
        "external_fasta": str(external),
        "host_sha256": host_sha256,
        "external_sha256": external_sha256,
        "external_prefix": EXTERNAL_PREFIX,
        "bowtie2_version": bowtie2_version,
        "bowtie2_index_compatibility": ".".join(bowtie2_version.split(".")[:2]),
        "index_basename": INDEX_BASENAME,
        "threads": args.threads,
        "build_timestamp": __import__("datetime").datetime.now(
            __import__("datetime").timezone.utc).isoformat(),
    }

    def build(directory):
        return build_into(directory, host, external, contigs, manifest)

    if args.cache_dir:
        final_dir = pathlib.Path(args.cache_dir) / cache_key
        if final_dir.exists() and not entry_is_complete(final_dir, cache_key):
            resolved = replace_stale_entry(args.cache_dir, cache_key, build)
        else:
            resolved = publish(args.cache_dir, cache_key, build)
    else:
        resolved = build(pathlib.Path(args.output_dir))

    print(resolved)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:  # surfaced to Nextflow as a task failure
        print(f"{type(error).__name__}: {error}", file=sys.stderr)
        sys.exit(1)
