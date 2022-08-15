#!/usr/bin/env Rscript

## checks samplesheet for proper column names and creates and ID variable
miss_err <- function(miss){
	paste("ERROR: Not all required columns are present in the samplesheet.\n
	      Missing columns:", paste(miss, collapse = " "))
}
dup_err <- function(dup){
	paste("ERROR: Not all sample IDs are unique.\n
	      Duplicate ID(s):", paste(dup, collapse = " "))
}

args <- commandArgs(trailingOnly = T)

SS <- read.csv(args[1], colClasses = "character", na.strings = c("", "NA"), check.names = F)
workflow <- args[2]

cols <- c("R1", "R2", "SampleID", "Cell Line", "Antibody", "Treatment", "Replicate")

if(workflow == "single"){
	missing <- !(cols %in% colnames(SS))
	if( any(missing) ) {

		missing_cols <- cols[which(missing)]
		stop(miss_err(missing_cols))

	} else {

		SS$ID <- apply(SS[cols[-c(1,2)]], 1, function(x) paste(x[!is.na(x)], collapse = "_"))
		dup <- duplicated(SS$ID)
		if(any(dup)) {

			stop(dup_err(SS$ID[dup]))

		} else {

			write.csv(SS, "samplesheet_uniqID.csv", quote = F, row.names = F)

		}
	}
}

if(workflow == "group") {
	cols <- append(cols, "group")
	missing <- !(cols %in% colnames(SS))
	if( any(missing) ) {

		missing_cols <- cols[which(missing)]
		stop(miss_err(missing_cols))

	} else {

		SS$ID <- apply(SS[cols[-c(1,2)]], 1, function(x) paste(x[!is.na(x)], collapse = "_"))
		dup <- duplicated(SS$ID)
		if(any(dup)) {

			stop(dup_err(SS$ID[dup]))

		} else {

			write.csv(SS, "samplesheet_uniqID.csv", quote = F, row.names = F)

		}
	}
}
