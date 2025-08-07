CUT&RUN
=======

A Nextflow DSL2 implementation of the Raab Lab CUT&RUN processing pipeline. Design modeled after the [nf-core](https://nf-co.re/cutandrun) implementation.

In Nextflow, data flows through **channels** and into **processes**,
which transforms the data in some way and produces an output that can be passed to another process.
Processes are similar to functions.
Similar processes are grouped into **modules**, which can be invoked in the main script.

Modules and processes are then organized into **workflows**,
which is a set of processes and channels that constitute the pipeline.

Components
==========

- [X] Sample Sheet
	- [X] Sample sheet from directory
	- [X] Sample sheet error checking
- [X] Trim and FastQC - TrimGalore
- [X] Alignment - Bowtie2
- [ ] Cat/merge across lanes
- [X] Sort and index - samtools
- [X] Peak calling - macs2
- [X] Consensus peak calling - MSPC
- [X] Insert size QC - picard
- [X] Remove duplicates - picard
- [X] Normalization factors - csaw
- [X] Coverage Tracks - deepTools
	- [X] Single-sample Depth Normalized
	- [X] Multi-sample Group Normalized
- [X] MultiQC report - multiQC
- [X] Airtable Integration
	- [X] Pull Experiment
	- [X] Update Sample Table
	- [X] Pull Samples

Usage
=====

To see example usage and available parameters, run:

    nextflow run raab-lab/cut-n-run --help

Basic Examples
--------------

Run standard CUT&RUN analysis:

    nextflow run . --sample_sheet /path/to/samplesheet.csv

Run with consensus peak calling (requires group_avg column in samplesheet):

    nextflow run . --sample_sheet /path/to/samplesheet.csv --call_consensus_peaks

Run with group normalization:

    nextflow run . --sample_sheet /path/to/samplesheet.csv --group_normalize

Run with both consensus peaks and normalization:

    nextflow run . --sample_sheet /path/to/samplesheet.csv --call_consensus_peaks --group_normalize

Customize MSPC parameters:

    nextflow run . --sample_sheet /path/to/samplesheet.csv --call_consensus_peaks --mspc_args "--weak 0.001 --strong 1e-09"

Getting Nextflow
----------------

The easiest way to get Nextflow is to simply load from Longleaf:

    module load nextflow

Since the pipeline is hosted on a private repo,
we need to set up an access token for automatic retrieval.

To do this go to your github settings and select "Developer settings".
Click the "Personal access tokens" tab and "Generate new token".
Set the expiration to whatever you like (just know you will have to do this again when it expires)
and check the "repo" box under scopes. Then "Generate token".

Once you have copied your token go to Longleaf
and create a file called `scm` in `~/.nextflow` with your favorite editor:

    vim ~/.nextflow/scm

The file should have the following structure:

    providers {
	    github {
		user = '<github username>'
		password = '<access token>'
	    }
    }

Save the file and then run:

    chmod go-rwx ~/.nextflow/scm

**This is important because the access token is essentially a password so keep it safe.**

Workflow Steps
--------------

This pipeline is implemented in three workflows, helper scripts for running each step can be found ![here](helper).

1. Create a barebones samplesheet from your fastq directory. This will only fill in fastq paths and the library ID (assumed to be everything before the first underscore in the filename), **so other meta data will need to be filled in manually according to the [sample sheet format](docs/params.md)**.

       sbatch create_samplesheet.sh

2. Trim reads and align, then find peaks, coverage, and other QC metrics. This step will output coverage tracks (bigwigs) and a QC report for judging sample quality and defining groupings for coverage normalization.

       sbatch cnr.sh

3. Lastly, calculate normalization factors with csaw (defaults to 'bin' method) and rescale coverage. This step calculates normalization factors based on the grouping defined in the samplesheet and outputs rescaled coverage tracks.

       sbatch normalize.sh

Consensus Peak Calling
----------------------

The pipeline includes optional consensus peak calling using MSPC (Multiple Sample Peak Calling) to identify reproducible peaks across biological replicates. This feature:

- Groups samples by the `group_avg` column in the samplesheet
- Requires minimum 2 replicates per group for consensus calling
- Outputs consensus peaks to `peaks/consensus_peaks/`
- Uses sensible defaults for all MSPC parameters

### Requirements

To use consensus peak calling, your samplesheet must include a `group_avg` column that defines which samples should be grouped together for consensus calling.

Example samplesheet with group_avg column:
```
R1,R2,SampleNumber,SampleID,Cell Line,Genotype,Antibody,Treatment,Replicate,group_avg
/path/to/sample1_R1.fastq.gz,/path/to/sample1_R2.fastq.gz,1,Sample1,HeLa,WT,H3K4me3,Control,1,H3K4me3_Control
/path/to/sample2_R1.fastq.gz,/path/to/sample2_R2.fastq.gz,2,Sample2,HeLa,WT,H3K4me3,Control,2,H3K4me3_Control
/path/to/sample3_R1.fastq.gz,/path/to/sample3_R2.fastq.gz,3,Sample3,HeLa,WT,H3K4me3,Treatment,1,H3K4me3_Treatment
/path/to/sample4_R1.fastq.gz,/path/to/sample4_R2.fastq.gz,4,Sample4,HeLa,WT,H3K4me3,Treatment,2,H3K4me3_Treatment
```

### Default MSPC Parameters

- Weak threshold: 0.0001
- Strong threshold: 1e-08
- Gamma (combined p-value cutoff): 1e-12
- Score cutoff: 30
- Minimum overlap: 1

These can be customized using the `--mspc_args` parameter.

