raab-lab/cut-n-run: Changelog
==============================

The format of this changelog is based on the [nf-core](https://github.com/nf-core/rnaseq/blob/master/CHANGELOG.md) changelog.

## [2.2] - 2022-09-22

### Updates

This release adds an effective genome size parameter that is shared between bamCoverage and MAC2. The default is the effective human genome size for 50bp reads (see https://deeptools.readthedocs.io/en/latest/content/feature/effectiveGenomeSize.html). While we don't apply a mapping filter, we may in the future.

### Parameters

| Old parameters         | New parameters         |
| ---------------------- | ---------------------- |
|                        | `--genomeSize`         |

## [2.1] - 2022-08-26

:exclamation: Big Enhancement

This release integrates Airtable into the pipeline. This should facilitate easier sample sheet creation and provide a single location for all sequencing data to be stored. Additionally, a help parameter was added to display help information (along with extensive doc updates in general).

### Parameters

| Old parameters         | New parameters         |
| ---------------------- | ---------------------- |
|                        | `--new_experiment`     |
|                        | `--pull_samples`	  |
|                        | `--help`	 	  |

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
