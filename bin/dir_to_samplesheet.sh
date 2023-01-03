#!/bin/bash

DIR=$1

if [[ ! -d "$DIR" ]]
then
	echo "Fastq inventory not found."
	exit 1
else

	HEADER="R1,R2,SampleID,Cell Line,Antibody,Treatment,Replicate"
	echo $HEADER > samplesheet.csv

	for R1 in ${DIR}/*R1_001.fastq.gz; do
		R2=$(echo $R1 | sed 's/R1_001/R2_001/')
		lib_id=$(basename $R1 | sed 's/_.*//')

		pR1=$(realpath $R1)
		pR2=$(realpath $R2)

		## build samplesheet
		echo $pR1,$pR2,$lib_id,,,, >> samplesheet.csv

	done

fi
