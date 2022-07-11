Parameters
==========

Defaults can be found either in nextflow.config or main.nf.

Nextflow
--------

`--sample_sheet`

Path to the experiment samplesheet in csv format. It should be formatted as follows:

|Column	        |Description					|
|---------------|-----------------------------------------------|
|read1		|Full path to the first read 			|
|read2		|Full path to the second read 			|
|lib_id		|Unique sequencing library ID		   	|
|cell_line	|Cell line identifier (i.e. HepG2)		|
|antibody	|Antibody used					|
|treatment	|Treatment or experimental conditions		|
|replicate	|Experimental replicate number			|
|group		|Normalization group				|
