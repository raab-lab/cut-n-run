#!/bin/bash

DIR=$1

if [[ ! -d "$DIR" ]]
then
	echo "Fastq inventory not found."
	exit 1
else

	HEADER=read1,read2,lib_id,cell_line,antibody,treatment,replicate
	echo $HEADER > samplesheet.csv

	for R1 in ${DIR}/*R1_001.fastq.gz; do
		R2=$(echo $R1 | sed 's/R1_001/R2_001/')

		pR1=$(realpath $R1)
		pR2=$(realpath $R2)

		## build samplesheet
		echo $pR1,$pR2,,,,, >> samplesheet.csv

	done

fi
