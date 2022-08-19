#!/bin/bash

module add nextflow
source ~/.secrets

## MODIFY THE EXPERIMENT ID FOR THE EXPERIMENT YOU WANT TO RUN
nextflow run raab-lab/cut-n-run \
	--new_experiment $1 \
	-r dev \
	-latest
