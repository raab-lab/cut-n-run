#!/usr/bin/env Rscript

## Verification for the reviewed SRA manifest validator.
## Run with: Rscript --vanilla tests/test_sra_manifest.R

source("bin/check_sra_manifest.R")

expect_error <- function(expr, pattern) {
	message <- tryCatch({ force(expr); "" }, error = conditionMessage)
	if (!grepl(pattern, message)) {
		stop("expected error matching '", pattern, "' but got: '", message, "'")
	}
}

## Write a mutated copy of a fixture to a temporary file and validate it.
with_mutation <- function(path, mutate) {
	x <- read.csv(path, colClasses = "character", check.names = FALSE,
		      na.strings = c("", "NA"))
	x <- mutate(x)
	tmp <- tempfile(fileext = ".csv")
	write.csv(x, tmp, row.names = FALSE, quote = TRUE, na = "")
	on.exit(unlink(tmp), add = TRUE)
	validate_sra_manifest(tmp)
}

valid_path <- "tests/fixtures/sra_manifest_valid.csv"
multi_path <- "tests/fixtures/sra_manifest_multirun.csv"

## A single reviewed paired Illumina run validates and is returned intact.
valid <- validate_sra_manifest(valid_path)
stopifnot(identical(valid$Run, "SRR10000001"))
stopifnot(identical(valid$SampleID, "Sample1"))

## Provenance columns that the mapping workflow does not interpret are retained.
stopifnot(all(c("geo_series", "geo_sample") %in% names(valid)))

## Multiple runs for one library are accepted and sorted into a stable order.
multi <- validate_sra_manifest(multi_path)
stopifnot(identical(multi$Run, sort(multi$Run)))
stopifnot(length(unique(multi$SampleID)) == 1L)
stopifnot(nrow(multi) == 2L)

## The shipped invalid fixture is rejected.
expect_error(validate_sra_manifest("tests/fixtures/sra_manifest_invalid.csv"),
	     "duplicate Run|PAIRED|ILLUMINA|conflicting metadata")

## A run accession may occur only once.
expect_error(
	with_mutation(multi_path, function(x) { x$Run <- x$Run[1]; x }),
	"duplicate Run")

## Accessions must look like SRR run accessions.
expect_error(
	with_mutation(valid_path, function(x) { x$Run <- "ERX999999"; x }),
	"Malformed SRR accession")

## This workflow is paired-end only.
expect_error(
	with_mutation(valid_path, function(x) { x$LibraryLayout <- "SINGLE"; x }),
	"PAIRED")

## Non-Illumina platforms are refused.
expect_error(
	with_mutation(valid_path, function(x) { x$Platform <- "OXFORD_NANOPORE"; x }),
	"ILLUMINA")

## Required fields may not be blank.
expect_error(
	with_mutation(valid_path, function(x) { x$Antibody <- NA_character_; x }),
	"blank required fields")

## Runs sharing a SampleID must agree on every biological field.
expect_error(
	with_mutation(multi_path, function(x) { x$Treatment[2] <- "EPZ"; x }),
	"conflicting metadata")

## A missing required column is reported by name.
expect_error(
	with_mutation(valid_path, function(x) { x[setdiff(names(x), "Genotype")] }),
	"Missing SRA manifest columns: Genotype")

## An empty manifest is rejected rather than silently producing no samples.
expect_error(
	with_mutation(valid_path, function(x) x[0, , drop = FALSE]),
	"no rows")

## Layout and platform checks are case-insensitive.
lower <- with_mutation(valid_path, function(x) {
	x$LibraryLayout <- "paired"
	x$Platform <- "illumina"
	x
})
stopifnot(nrow(lower) == 1L)

cat("SRA manifest validation OK\n")
