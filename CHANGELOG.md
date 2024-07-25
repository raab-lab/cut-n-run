raab-lab/cut-n-run: Changelog
==============================

The format of this changelog is based on the [nf-core](https://github.com/nf-core/rnaseq/blob/master/CHANGELOG.md) changelog.

## [4.1] - 2024-07-25

### Updates

- This release deprecates the atac-seq pipeline in favor of running cut&run in 'ATAC' mode.

### Parameters

| Old parameters         | New parameters         |
| ---------------------- | ---------------------- |
|                        | `--mode`	          |
|                        | `--exclusionList`      |


## [4.0] - 2024-02-08

:exclamation: Major Release

This release introduces changes to the sample sheet and changes the way normalization happens

### Updates

- The samplesheet now includes a new column called `params` (see [docs](docs/params.md)).
- Deprecated --norm_method parameter in favor of adding normalization parameters to the samplesheet.

| Old parameters         | New parameters         |
| ---------------------- | ---------------------- |
| `--norm_method`        | 		          |

## [3.2] - 2024-02-01

### Updates

- Adds a column for the unscaled norm factor in the CSAW output.

## [3.1] - 2023-11-20

I thought the last release fixed the wiggletools error but I guess not :weary:.
This one should do it. For real this time.

### Updates

- Runs `wiggletools mean` in a singularity container. Using `exec`, this conveniently outputs the results to stdout
which is then parsed and converted to bigWig format using the `ucsctools` module. No more conda.

## [3.0] - 2023-09-06

:exclamation: Major Release

This release bumps several tool versions and introduces some changes.

### Updates

- The samplesheet now includes a new column called SampleNumber (see [docs](docs/params.md) for example)
- Bumped to pyairtable to version 2.1.0.post1 and refactored airtable scripts to accomodate
- Airtable is deprecating API keys, so code was refactored to take personal access tokens
- Bumped the nextflow version to the latest on longleaf,
which fixed the conda error when trying to average bigWigs with wiggletools

## [2.4.1] - 2023-04-27

Updates to latest trim galore module on longleaf to fix missing cutadapt error.

## [2.4] - 2023-03-16

### Updates

This release adds extra macs2 parameters. There is now an option for broad peak calling and
for modifying the p-value (technically q-value) for macs for what peaks end up in the file.

### Parameters

| Old parameters         | New parameters         |
| ---------------------- | ---------------------- |
|                        | `--broad`	          |
|                        | `--macs_qvalue`        |

## [2.3.1] - 2023-02-22

### Updates

This small release adds an option to use the `-profiles` parameter. Profiles allow you to set a group of variables all at once.
The implemented profiles specifically simplify changing species specific parameters (mm10 vs hg38). See docs for usage.

### Parameters

| Old parameters         | New parameters         |
| ---------------------- | ---------------------- |
|                        | `-profile`	          |


## [2.3] - 2022-09-30

### Updates

This release adds multiple new parameters and new functionality. A filtering step has been added to the samtools module that that removes reads with low mapping quality. This MAPQ cutoff has been added as a parameter. Additionally, bigWig files are now averaged for easier visualization using wiggletools. The samplesheet now requires two grouping columns, one for scale factor normalization, and one for bigWig averaging. For bigWig averaging, we need chromosome sizes, which are directly downloaded from UCSC. Also the csaw normalization method parameter was previously undocumented but has now been added.

### Parameters

| Old parameters         | New parameters         |
| ---------------------- | ---------------------- |
|                        | `--genome`	          |
|                        | `--skip_filter`        |
|                        | `--mapq`	          |
|                        | `--norm_method`        |

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
