#!/bin/bash

#SBATCH -c 2

#SBATCH --mem=10G

#SBATCH -t 24:00:00

#SBATCH -J NF

module add nextflow
source ~/.secrets/airtable

## MODIFY THE EXPERIMENT ID, WORK, OUTPUT, AND EMAIL FOR YOUR RUN
nextflow run raab-lab/cut-n-run \
		--pull_samples EXPERIMENT ID \
		-profile mm10/hg38 \
		-w /path/to/work \
		--outdir /path/to/Output \
		-with-report \
		-N <user@email.edu> \
		-latest \
		-ansi-log false \
		-resume
