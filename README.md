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
	- [ ] Sample sheet from directory
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

To download Nextflow:

    $ curl -s https://get.nextflow.io | bash

This will download the nextflow binary to the current dir.
I keep this in ~/.local/bin so I can run nextflow straight from the command line:

    ## Run if you don't have .local/bin
    $ ## mkdir -p ~/.local/bin
    $ mv nextflow ~/.local/bin

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

Running Nextflow
----------------

Before anything else, ensure that you have the most up to date version of the pipeline
by running:

    $ nextflow pull raab-lab/cut-n-run

Nextflow will also warn you if you are behind versions,
but this may be missed when you submit to the cluster.

To run the CUT&RUN pipeline from start to finish, submit it as a job to the cluster:

    $ sbatch -t 24:00:00 -J "NF" --mem=10G -c 2 --wrap="nextflow run raab-lab/cut-n-run \
								--sample_sheet samplesheet.csv \
								-w work \
								-with-report \
								-N <user@email.edu> \
								-latest \
								-resume"

The samplesheet should be formatted as specified [here](docs/params.md). Pipeline outputs can be found in the `Output` folder.

Workflow Steps
--------------

This pipeline is implemented in two steps:

1. Trim reads and align, then find peaks, coverage, and other QC metrics. This step will output coverage tracks (bigwigs) and a QC report for judging sample quality and defining groupings for coverage normalization. To just run this step add `-entry CHECK_SAMPLES` to the above command.

2. Calculate normalization factors with csaw (defaults to 'bin' method) and rescale coverage. This step calculates normalization factors based on the grouping defined in the samplesheet and outputs rescaled coverage tracks. To run this step simply run the above command.
