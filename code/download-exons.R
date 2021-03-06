#!/usr/bin/env Rscript

# Download exons for counting reads per gene with Subread featureCounts.
#
# To submit on RCC Midway:
#
#   sbatch --mem=2G --partition=broadwl download-exons.R <file.saf>
#
# Notes:
#
#  * View available Ensembl archives at http://www.ensembl.org/info/website/archives/index.html
#  * Output is in Simplified Annotation Format (SAF)
#     * Columns: GeneID, Chr, Start, End, Strand
#     * Coordinates are 1-based, inclusive on both ends
#  * Contains duplicate and overlapping exons (featureCounts handles this)
#  * Only contains exons with gene_biotype of protein_coding
#  * See ?Rsubread::featureCounts for more details

# Input ------------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1)
# The file to save the exon coordinates in SAF format
output_file <- args[1]

# The Ensembl archive
archive <- "may2017.archive.ensembl.org"

# Setup ------------------------------------------------------------------------

suppressMessages(library("biomaRt"))

dir.create(dirname(output_file), showWarnings = FALSE, recursive = TRUE)

ensembl <- useMart(host = archive,
                   biomart = "ENSEMBL_MART_ENSEMBL",
                   dataset = "mmusculus_gene_ensembl")

# Download exons ---------------------------------------------------------------

exons_all <- getBM(attributes = c("ensembl_gene_id", "ensembl_exon_id",
                                  "chromosome_name", "exon_chrom_start",
                                  "exon_chrom_end", "strand",
                                  "external_gene_name", "gene_biotype"),
                   mart = ensembl)

exons_final <- exons_all[exons_all$chromosome_name %in% c(1:19, "X", "Y", "MT") &
                         exons_all$gene_biotype == "protein_coding",
                         c("ensembl_gene_id", "chromosome_name",
                           "exon_chrom_start", "exon_chrom_end",
                           "strand", "external_gene_name",
                           "gene_biotype")]
colnames(exons_final) <- c("GeneID", "Chr", "Start", "End", "Strand",
                           "Name", "Biotype")
# Sort by Ensembl gene ID, then start and end positins
exons_final <- exons_final[order(exons_final$GeneID,
                                 exons_final$Start,
                                 exons_final$End), ]
# Fix strand
exons_final$Strand <- ifelse(exons_final$Strand == 1, "+", "-")

# Save as tab-separated file in Simplified Annotation Format (SAF)
write.table(exons_final, output_file, quote = FALSE, sep = "\t",
            row.names = FALSE)
