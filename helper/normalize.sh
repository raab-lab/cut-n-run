#!/bin/bash

#SBATCH -c 2

#SBATCH --mem=10G

#SBATCH -t 24:00:00

#SBATCH -J NF

module add java/17.0.2
module add nextflow

## MODIFY THE SAMPLESHEET AND EMAIL FOR YOUR RUN
nextflow run raab-lab/cut-n-run \
		--sample_sheet /path/to/samplesheet \
		--group_normalize \
		-profile mm10/hg38 \
		-w /path/to/work \
		--outdir /path/to/Output \
		-with-report \
		-N <user@email.edu> \
		-latest \
		-ansi-log false \
		-resume
