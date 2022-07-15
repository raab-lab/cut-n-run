#!/usr/bin/env Rscript

## checks samplesheet for proper column names and creates and ID variable
err <- function(miss){
	paste("ERROR: Not all required columns are present in the samplesheet.\n
	      Missing columns:", paste(miss, collapse = " "))
}
args <- commandArgs(trailingOnly = T)

SS <- read.csv(args[1])
workflow <- args[2]

cols <- c("read1", "read2", "lib_id", "cell_line", "antibody", "treatment", "replicate")

if(workflow == "single"){
	missing <- !(cols %in% colnames(SS))
	if( any(missing) ) {

		missing_cols <- cols[which(missing)]
		stop(err(missing_cols))

	} else {

		SS$ID <- with(SS, paste(lib_id, cell_line, antibody, treatment, replicate, sep = "_"))
		write.csv(SS, "samplesheet_uniqID.csv", quote = F, row.names = F)

	}
}

if(workflow == "group") {
	cols <- append(cols, "group")
	missing <- !(cols %in% colnames(SS))
	if( any(missing) ) {

		missing_cols <- cols[which(missing)]
		stop(err(missing_cols))

	} else {

		SS$ID <- with(SS, paste(lib_id, cell_line, antibody, treatment, replicate, sep = "_"))
		write.csv(SS, "samplesheet_grouped.csv", quote = F, row.names = F)

	}
}
