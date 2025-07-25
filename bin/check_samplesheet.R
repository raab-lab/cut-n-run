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

cols <- c("R1", "R2", "SampleNumber", "SampleID", "Cell Line", 'Genotype', "Antibody", "Treatment", "Replicate")

if(workflow == "single"){
	if( !("SampleNumber" %in% colnames(SS)) ) {
		SS$SampleNumber <- seq_along(nrow(SS))
	}
	missing <- !(cols %in% colnames(SS))
	if( any(missing) ) {

		missing_cols <- cols[which(missing)]
		stop(miss_err(missing_cols))

	} else {

		SS$ID <- apply(SS[cols[-c(1,2,3)]], 1, function(x) paste(x[!is.na(x)], collapse = "_"))
		dup <- duplicated(SS$ID)
		if(any(dup)) {

			stop(dup_err(SS$ID[dup]))

		} else {

			SS$ID <- paste0(SS$SampleNumber, "_", SS$ID)
			write.csv(SS, "samplesheet_uniqID.csv", quote = F, row.names = F)

		}
	}
}
## TODO add PARAMS COLUMN
if(workflow == "group") {
	cols <- append(cols, c("group_norm", "group_avg", "params"))
	if( !("SampleNumber" %in% colnames(SS)) ) {
		SS$SampleNumber <- seq_along(nrow(SS))
	}
	missing <- !(cols %in% colnames(SS))
	if( any(missing) ) {

		missing_cols <- cols[which(missing)]
		stop(miss_err(missing_cols))

	} else {

		SS$ID <- apply(SS[cols[-c(1,2,3)]], 1, function(x) paste(x[!is.na(x)], collapse = "_"))
		dup <- duplicated(SS$ID)
		if(any(dup)) {

			stop(dup_err(SS$ID[dup]))

		} else {

			SS$ID <- paste0(SS$SampleNumber, "_", SS$ID)
			write.csv(SS, "samplesheet_uniqID.csv", quote = F, row.names = F)

		}
	}
}
