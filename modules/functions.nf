def helpMessage() { 
"""\
	==========================================================================================
	______            _       _           _       _____ _   _ _____      ______ _   _ _   _ 
	| ___ \\          | |     | |         | |     /  __ \\ | | |_   _|__   | ___ \\ | | | \\ | |
	| |_/ /__ _  __ _| |__   | |     __ _| |__   | /  \\/ | | | | |( _ )  | |_/ / | | |  \\| |
	|    // _` |/ _` | '_ \\  | |    / _` | '_ \\  | |   | | | | | |/ _ \\/\\|    /| | | | . ` |
	| |\\ \\ (_| | (_| | |_) | | |___| (_| | |_) | | \\__/\\ |_| | | | (_>  <| |\\ \\| |_| | |\\  |
	\\_| \\_\\__,_|\\__,_|_.__/  \\_____/\\__,_|_.__/   \\____/\\___/  \\_/\\___/\\/\\_| \\_|\\___/\\_| \\_/
	===========================================================================================
	\033[1;34mUsage\033[0m:
	nextflow run raab-lab/cut-n-run (--create_samplesheet|--sample_sheet) </path/>
	nextflow run raab-lab/cut-n-run (--new_experiment|--pull_samples) <ID>

	\033[1;34mArguments\033[0m:
	--help
		Display this message

	--create_samplesheet </path/>
		Path to a directory of fastq.gz files

	--sample_sheet </path/>
		Path to CSV with fastq paths and sample metadata

	--new_experiment <ID>
		Experiment ID for new experiment to add to airtable

	--pull_samples <ID>
		Experiment ID to pull from airtable to run through pipeline

	--group_normalize
		Flag to use csaw to normalize coverage tracks using 'group' [Default: false]

	-w </path/>
		Path to your desired work directory for intermediate output [Default: work]

	--outdir </path/>
		Path to your desired output directory [Default: Output]

	\033[1;34mTool Options\033[0m:
	--bt2_index </path/>
		Path to Bowtie2 index [Default:/proj/seq/data/hg38_UCSC/Sequence/Bowtie2Index/]

	--genomeSize <numeric>
		Effective genome size for MACS2 and bamCoverage (see docs for more info) [Default: 2701495761]

	\033[1;34mArguments to Always Include\033[0m:
	-latest
		Flag to pull the latest pipeline release from GitHub

	-with-report
		Flag to output a run report

	-N <user@email.edu>
		Email address to notify when the pipeline has finished

	-resume
		Flag to pick back up from last pipeline execution (works even if first time)

""".stripIndent()

}
