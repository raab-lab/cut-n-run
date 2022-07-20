#!/bin/bash

#SBATCH -c 2

#SBATCH --mem=10G

#SBATCH -t 5:00

#SBATCH -J NF

module add nextflow

nextflow run raab-lab/cut-n-run \
		--create_samplesheet /full/path/to/fastq/dir \
		-latest \
		-ansi-log false
