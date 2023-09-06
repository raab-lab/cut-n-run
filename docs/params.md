Parameters
==========

Defaults can be found either in nextflow.config or main.nf.

`--sample_sheet`

Path to the experiment samplesheet in csv format. It should be formatted as follows:

|Column	        |Description					|
|---------------|-----------------------------------------------|
|R1		|Full path to the first read 			|
|R2		|Full path to the second read 			|
|SampleNumber	|Immutable SampleNumber (Airtable)	  	|
|SampleID	|Unique sequencing library ID		   	|
|Cell Line	|Cell line identifier (i.e. HepG2)		|
|Antibody	|Antibody used					|
|Treatment	|Treatment or experimental conditions		|
|Replicate	|Experimental replicate number			|
|group_norm	|Scale factor normalization group (optional)	|
|group_avg	|BigWig Averaging group (optional)		|

Example:

    R1,R2,SampleNumber,SampleID,Cell Line,Antibody,Treatment,Replicate
    /path/to/R1,/path/to/R2,626,UniqID,HepG2,ARID1A,Sorafenib,1

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

Flag to use csaw to normalize and average coverage tracks using 'group_norm' and 'group_avg', respectively [Default: false]

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

`--genome <value>`

Genome to pull chromosome sizes from UCSC [Default: hg38]
The module uses the script fetchChromSizes provided by UCSC,
so only UCSC genome names are allowed i.e. hg38, mm10, etc.
See https://hgdownload.cse.ucsc.edu/admin/exe/linux.x86_64/fetchChromSizes

`--norm_method` <value>

Normalization method to use for scaling coverage tracks. Either 'bins' or 'peaks' [Default: bins]

`--macs_qvalue` <value>

Sets the q-value cutoff for macs `-q` parameter. [Default: 0.05]

`--broad` <value>

Turns on broad peak calling. Must also supply a p(q)-value cutoff for what peaks to include in output. If unset then narrow peak calling with `--call-summits -q $macs_qvalue` is used. [Default: false]

`--skip_filter`

Flag to skip filtering of low quality alignments [Default: false]

`--mapq <numeric>`

Only include alignments with MAPQ >= <numeric> [Default: 10]

`-profile`

Sets species specific variables. Either 'hg38' or 'mm10'.
The default pipeline parameters correspond to `-profile hg38`

`-latest`

Flag to pull the latest pipeline release from GitHub

`-with-report`

Flag to output a run report

`-N <user@email.edu>`

Email address to notify when the pipeline has finished

`-resume`

Flag to pick back up from last pipeline execution (works even if first time)
