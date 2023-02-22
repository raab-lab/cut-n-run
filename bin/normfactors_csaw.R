#!/usr/bin/env Rscript 
doc <- 'calculate_normfactors_csaw.R

Usage: 
  calculate_normfactors_csaw.R (--bins| --peaks) [--winSize=<winsize> --binSize=<binsize> --threshold=<threshold> --keepdup --pe=<pe> --maxFrag=<maxFrag>] <OUTPUT> <FILES>... 
  calculate_normfactors_csaw.R (-h | --help)

Options: 
  -h --help                     Show this screen
  --peaks                       Use normalization for efficiency from csaw.
  --bins                        Use normalization for composition from csaw. 
  --winSize=val                 Size of windows for efficency method [default: 200].
  --binSize=val                 Size of bins for composition method or background for efficiency [default: 10000].
  --threshold=val               Log2 Fold enrichment to decided number of regions to keep [default: 3]
  --keepdup                     flag for readParam object to keep marked duplicates
  --pe=both                     flag for readParam object to set paired read. One of both, none, first, or second [default: both]
  --maxFrag=val                 flag for readParam object to set maximum fragment size [default: 500]
' 
################################################################################
#  METHOD: one of 'peaks' or 'bins'
#     Peaks is TMM on high-abundance regions. Assumption is few differential binding events and
#               differences between samples are technical variation
#     Bins is TMM On bins (10kb default). No assumption of global trends 
#                and most bins represent non-differntially bound background regions
# 
# See section 5.4 in https://bioconductor.org/books/3.13/csawBook/chap-norm.html 
#      for additional normalization information
# Calculation comes from discussion at 
#    https://www.biostars.org/p/413626/#414440
#    https://support.bioconductor.org/p/124180/
################################################################################
suppressMessages(library(docopt))
suppressMessages(library(csaw))

args <- docopt(doc)
# if (sum(args$efficiency, args$composition) == 2) {
#   stop(print ('Choose either --bins or --peaks'))
# } 
# if (args$bins) { 
#   method <- 'bins'}  
# if (args$composition) { 
#   method <- 'peaks'
# }
# if (!exists('method')) { stop(print('Must choose either --bins or --peaks'))}

bamFiles <- args$FILES
if (length(bamFiles) < 2) { stop(print('Input should be at least two bamfiles'))}

binSize <- as.numeric(args$binSize)
winSize <- as.numeric(args$winSize)
threshold <- as.numeric(args$threshold)
maxFrag <- as.numeric(args$maxFrag)
readType <- args$pe
dedup <- !args$keepdup

# Read in params
param <- readParam(pe = readType, 
                   max.frag = maxFrag,
                   dedup = dedup)

if (args$peaks) {
  message("Computing efficiency (peak) normalization factors")
  wc <- windowCounts(bamFiles, 
                     width = winSize, 
                     param = param)
  background <- windowCounts(bamFiles, 
                             bin = TRUE, 
                             width = binSize, 
                             param = param) 
  keep <- filterWindowsGlobal(wc, background)$filter > log2(threshold) 
  filtered_wc <- wc[keep,]
  filtered_wc <- normFactors(filtered_wc)
  nf <- filtered_wc$norm.factors
  totals <- filtered_wc$totals
  scale_factors <- 1/(totals*(nf/1e6) )
  bam <- normalizePath(colData(wc)$bam.files) 
}

if (args$bins) {
  message("Computing composition (bin) normalization factors")
  binned <- windowCounts(bamFiles, 
                         bin = TRUE, 
                         width = binSize, 
                         param = param) 
  binned <- normFactors(binned) 
  nf <- binned$norm.factors
  totals <- binned$totals
  scale_factors <- 1 / ( totals*(nf/1e6) )
  bam <- normalizePath(binned$bam.files)
}

bai <- gsub("[.]bam", ".bai", bam)
id <- gsub("_sorted_markdup.bam", "", basename(bam))
nf_out <- data.frame(id = id, bam = bam, bai = bai, scale_factors = scale_factors)
write.table(nf_out, file = args$OUTPUT, row.names = F, col.names = T, sep = ',', quote = F)


