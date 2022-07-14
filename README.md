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

## Tools to implement

- [ ] Sample Sheet
	- [X] Sample sheet from directory
	- [ ] Sample sheet error checking
- [X] Trim and FastQC
- [X] Alignment
- [ ] Cat/merge across lanes
- [X] Sort and index
- [X] Peak calling
- [X] Insert size QC
- [X] Remove duplicates
- [X] Normalization factors
- [X] Coverage Tracks
	- [X] Single-sample Depth Normalized
	- [X] Multi-sample Group Normalized
- [X] MultiQC report

Usage
=====

Getting Nextflow
----------------

The easiest way to get Nextflow is to simply load from Longleaf:

    $ module load nextflow

Since the pipeline is hosted on a private repo,
we need to set up an access token for automatic retrieval.

To do this go to your github settings and select "Developer settings".
Click the "Personal access tokens" tab and "Generate new token".
Set the expiration to whatever you like (just know you will have to do this again when it expires)
and check the "repo" box under scopes. Then "Generate token".

Once you have copied your token go to Longleaf
and create a file called `scm` in `~/.nextflow` with your favorite editor:

    $ vim ~/.nextflow/scm

The file should have the following structure:

    providers {
	    github {
		user = '<github username>'
		password = '<access token>'
	    }
    }

Save the file and then run:

    $ chmod go-rwx ~/.nextflow/scm

**This is important because the access token is essentially a password so keep it safe.**

Workflow Steps
--------------

This pipeline is implemented in three workflows:

1. Create a barebones samplesheet from your fastq directory. This will only fill in fastq paths for you, **so other meta data will need to be filled in manually according to the [sample sheet format](docs/params.md)**.

         $ nextflow run raab-lab/cut-n-run \
				--create_samplesheet /full/path/to/fastq/dir/ \
				-latest


2. Trim reads and align, then find peaks, coverage, and other QC metrics. This step will output coverage tracks (bigwigs) and a QC report for judging sample quality and defining groupings for coverage normalization.

        $ sbatch -t 24:00:00 -J NF --mem=10G -c 2 --wrap="nextflow run raab-lab/cut-n-run \
								--sample_sheet /path/to/samplesheet \
								-w work \
								-with-report \
								-N <user@email.edu> \
								-latest \
								-ansi-log false \
								-resume"

3. Lastly, calculate normalization factors with csaw (defaults to 'bin' method) and rescale coverage. This step calculates normalization factors based on the grouping defined in the samplesheet and outputs rescaled coverage tracks.

        $ sbatch -t 24:00:00 -J NF --mem=10G -c 2 --wrap="nextflow run raab-lab/cut-n-run \
								--sample_sheet /path/to/samplesheet \
								--group_normalize \
								-w work \
								-with-report \
								-N <user@email.edu> \
								-latest \
								-ansi-log false \
								-resume"
