#!/usr/bin/env Rscript

## Validates a reviewed SRA run manifest and normalizes its row order.
##
## The pipeline never infers a biological comparison from a GEO series, so this
## checks a reviewed one-row-per-SRR manifest rather than a bare accession.
## Columns beyond the required set (GEO provenance, grouping, normalization)
## are retained untouched.

required_sra_columns <- c(
  "Run", "SampleID", "Cell Line", "Genotype", "Antibody", "Treatment",
  "Replicate", "LibraryLayout", "Platform"
)

## Fields that must agree across every run assigned to one SampleID.
biological_sra_columns <- c(
  "Cell Line", "Genotype", "Antibody", "Treatment", "Replicate"
)

validate_sra_manifest <- function(path) {
  x <- read.csv(path, colClasses = "character", check.names = FALSE,
                na.strings = c("", "NA"))
  missing <- setdiff(required_sra_columns, names(x))
  if (length(missing)) stop("Missing SRA manifest columns: ", paste(missing, collapse = ", "))
  if (!nrow(x)) stop("SRA manifest has no rows")
  if (anyNA(x[required_sra_columns])) stop("SRA manifest has blank required fields")
  if (any(!grepl("^SRR[0-9]+$", x$Run))) stop("Malformed SRR accession")
  if (anyDuplicated(x$Run)) stop("SRA manifest contains duplicate Run accessions")
  if (any(toupper(x$LibraryLayout) != "PAIRED")) stop("LibraryLayout must be PAIRED")
  if (any(toupper(x$Platform) != "ILLUMINA")) stop("Platform must be ILLUMINA")

  # The checked manifest is written unquoted, matching check_samplesheet.R,
  # because Nextflow's splitCsv retains quote characters in the parsed keys and
  # values. Reject any content that would need quoting rather than emit it.
  unquotable <- vapply(x, function(v) any(grepl('[,"]', v, useBytes = TRUE)),
                       logical(1))
  if (any(unquotable)) {
    stop("SRA manifest fields must not contain commas or double quotes; ",
         "offending column(s): ", paste(names(unquotable)[unquotable], collapse = ", "))
  }

  by_sample <- split(x, x$SampleID)
  conflict <- vapply(by_sample, function(one) {
    any(vapply(one[biological_sra_columns], function(v) length(unique(v)) != 1L, logical(1)))
  }, logical(1))
  if (any(conflict)) stop("conflicting metadata for SampleID: ",
                          paste(names(conflict)[conflict], collapse = ", "))

  ## Stable accession order within each library is what the merge step relies on.
  x[order(x$SampleID, x$Run), , drop = FALSE]
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 1L) stop("usage: check_sra_manifest.R <sra_manifest.csv>")
  checked <- validate_sra_manifest(args[1])
  write.csv(checked, "sra_manifest_checked.csv", row.names = FALSE, quote = FALSE, na = "")
  message(sprintf("SRA manifest OK: %d runs across %d biological samples",
                  nrow(checked), length(unique(checked$SampleID))))
}
