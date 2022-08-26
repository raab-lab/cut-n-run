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

Airtable
---------

This pipeline interfaces with the Raab Lab airtable. To set up airtable, go to your account page and copy your personal API key (you made need to generate it first).

Now go to Longleaf and create a file called `.secrets` in your home directory:

    vim ~/.secrets

Add this line to the file:

    export AIRTABLE_API_KEY=YOUR_API_KEY

Save the file and then run:

    chmod go-rwx ~/.secrets

**This is important because the API key is essentially a password so keep it safe.**

Airtable Steps
--------------

Running the pipeline with airtable is implemented in 3 steps. Helper scripts can be found ![here](helper).

1. If you just received new data and need to process it for the first time, first fill out the Experiments table with the experiment type and where the raw fastq data is located (Data Directory). Then pull the new experiment, create a samplesheet, and update the samples table with the new samples. If you are re-running with an experiment already in the Samples *DONT RUN THIS STEP*, otherwise you'll duplicate records in the Samples table.

       new_experiment.sh <EXPERIMENT ID>

2. After filling in experiment metadata for your samples, pull them and run all the analyses from [step 2](#workflow-steps) of the workflow.

       sbatch pull_samples.sh

3. If you need to do group-wise normalization, simply run [step 3](#workflow-steps) as usual.

       sbatch normalize.sh

