Parameters
==========

Defaults can be found either in nextflow.config or main.nf.

`--sample_sheet`

Path to the experiment samplesheet in csv format. It should be formatted as follows:

|Column	        |Description					|
|---------------|-----------------------------------------------|
|R1		|Full path to the first read 			|
|R2		|Full path to the second read 			|
|SampleID	|Unique sequencing library ID		   	|
|Cell Line	|Cell line identifier (i.e. HepG2)		|
|Antibody	|Antibody used					|
|Treatment	|Treatment or experimental conditions		|
|Replicate	|Experimental replicate number			|
|Group		|Normalization group (optional)			|

Example:

    R1,R2,SampleID,Cell Line,Antibody,Treatment,Replicate
    /path/to/R1,/path/to/R2,UniqID,HepG2,ARID1A,Sorafenib,1

`--help`

Display a help message

`--create_samplesheet </path/>`

Path to a directory of fastq.gz files

`--sample_sheet </path/>`

Path to CSV with fastq paths and sample metadata

`--new_experiment <ID>`

Experiment ID for new experiment to add to airtable

`--pull_samples <ID>`

Experiment ID to pull from airtable to run through pipeline

`--group_normalize`

Flag to use csaw to normalize coverage tracks using 'group' [Default: false]

`-w </path/>`

Path to your desired work directory for intermediate output [Default: work]

`--outdir </path/>`

Path to your desired output directory [Default: Output]

`--bt2_index </path/>`

Path to Bowtie2 index [Default:/proj/seq/data/hg38_UCSC/Sequence/Bowtie2Index/]

`--genomeSize <numeric>`

Effective genome size for MACS2 and bamCoverage [Default: 2701495761]
See https://deeptools.readthedocs.io/en/latest/content/feature/effectiveGenomeSize.html
for info on choosing an effective size.

`-latest`

Flag to pull the latest pipeline release from GitHub

`-with-report`

Flag to output a run report

`-N <user@email.edu>`

Email address to notify when the pipeline has finished

`-resume`

Flag to pick back up from last pipeline execution (works even if first time)
