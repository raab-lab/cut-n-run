raab-lab/cut-n-run: Changelog
==============================

The format of this changelog is based on the [nf-core](https://github.com/nf-core/rnaseq/blob/master/CHANGELOG.md) changelog.

## [2.0] - 2022-07-20

### Updates

- The pipeline has been changed to a single workflow that uses `--group_normalize` to flag grouped coverage normalization, rather than two workflows that need `-entry`.
- A new parameter (and workflow) `--create_samplesheet` lets you create a basic sample sheet from a fastq directory.
- [Helper scripts](/helper) have been provided to make running the pipeline simpler.

### Parameters

| Old parameter          | New parameter          |
| ---------------------- | ---------------------- |
| `-entry CHECK_SAMPLES` |                        |
|                        | `--group_normalize`    |
|                        | `--create_samplesheet` |
