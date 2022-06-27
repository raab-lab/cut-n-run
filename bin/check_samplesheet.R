#!/usr/bin/env Rscript

## checks samplesheet for proper column names and creates and ID variable

args <- commandArgs(trailingOnly = T)

SS <- read.csv(args[1])
workflow <- args[2]

cols <- c("read1", "read2", "lib_id", "cell_line", "antibody")

if(workflow == "1"){
	if( any( !(cols %in% colnames(SS)) ) ){
		stop(paste("ERROR: Not all required columns are present in the samplesheet.
			   Required columns:", paste(cols, collapse = " ")))
	} else {
		SS$ID <- paste(SS$lib_id, SS$cell_line, SS$antibody, sep = "_")
		write.csv(SS, "samplesheet_uniqID.csv", quote = F, row.names = F)
	}
}

if(workflow == "2") {
	cols <- append(cols, "group")
	if( any( !(cols %in% colnames(SS)) ) ) {
		stop(paste("ERROR: Not all required columns are present in the samplesheet.
			   Required columns:", paste(cols, collapse = " ")))
	} else {
		SS$ID <- paste(SS$lib_id, SS$cell_line, SS$antibody, sep = "_")
		write.csv(SS, "samplesheet_grouped.csv", quote = F, row.names = F)
	}
}
