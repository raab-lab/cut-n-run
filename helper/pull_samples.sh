#!/bin/bash

#SBATCH -c 2

#SBATCH --mem=10G

#SBATCH -t 24:00:00

#SBATCH -J NF

## Test pyairtable version
module load python/3.12.4
PYAIRTABLE_VERSION=$(python -c "import pyairtable; print(pyairtable.__version__)")
if [[ $PYAIRTABLE_VERSION != '3.2.0' ]]; then
	echo "PLEASE UPDATE PYAIRTABLE"
	echo "module load python/3.12.4"
	echo "pip install --user pyairtable==3.2.0"
	exit 1
fi
module unload python

## Run workflow
module add nextflow
source ~/.secrets/airtable

## MODIFY THE EXPERIMENT ID, WORK, OUTPUT, AND EMAIL FOR YOUR RUN
nextflow run raab-lab/cut-n-run \
		--pull_samples EXPERIMENT ID \
		--mode cnr/atac \
		-profile mm10/hg38 \
		-w /path/to/work \
		--outdir /path/to/Output \
		-with-report \
		-N <user@email.edu> \
		-latest \
		-ansi-log false \
		-resume
