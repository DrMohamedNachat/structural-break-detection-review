# =============================================================================
# 00_run_all.R
# Run the complete pipeline
#
# Working directory = the project folder, which must contain the raw exports:
#   Wos_A_*.txt, WoS_B_*.txt      Web of Science plain-text exports (corpus A, B)
#   Scopus_A.csv, Scopus_B.csv    Scopus CSV exports (corpus A, B)
#   merged_data.rds               corpus of the first version of the search (1,796)
# The scripts live in R/ and write everything to output/, which they create.
#
# The raw exports are not redistributed with this repository (Scopus and Web of
# Science institutional licence). See data/README.md for what is released and
# appendix-a-search-strings.md for the queries that produce the exports.
#
# Steps
#   01  import + deduplication + exclusions (2026, retracted)   -> M_merged.rds
#   02b rule-based screening, strata, validation samples        -> M_screened.rds
#   03  bibliometric analyses, VOSviewer files                  -> tables, figures, M_tagged.rds
#   04  cross-citation between corpora A and B                  -> T10 tables, F10
#   05  comparison with the corpus of the first search          -> T11 tables
#   06  PRISMA flow diagram from the recorded counts            -> F1_prisma
#   07  sub-corpora, cross-citation detail, sensitivities       -> X1-X10 tables
#   08  validation of the screening rules and of the ML tag     -> V1-V5 tables
#   09  candidate set for the systematic-review screening       -> screening/
#
# Step 08 needs the coded validation files; see validation/README.md.
# =============================================================================

# setwd("path/to/project")

SCRIPTS <- c("01_import_merge.R", "02b_screening.R", "03_bibliometric_analysis.R",
             "04_cross_citation.R", "05_original_corpus_comparison.R", "06_prisma_figure.R",
             "07_additional_analyses.R", "08_validation.R", "09_screening_candidates.R")
LABELS <- c("import & merge", "screening", "bibliometric analysis", "cross-citation",
            "comparison with the first search", "PRISMA figure", "additional analyses",
            "validation", "screening candidates")

paths <- file.path("R", SCRIPTS)
missing <- paths[!file.exists(paths)]
if (length(missing)) stop("Scripts not found: ", paste(missing, collapse = ", "))

# Step 01 is the slow one; it is skipped when its output already exists.
RUN_IMPORT <- !file.exists("output/M_merged.rds")   # set TRUE to force a fresh import

# Step 08 reads the validation samples after they have been coded by hand. Step
# 02b writes them as blank templates, so on a fresh run there is nothing to
# validate yet and the step is skipped rather than failing.
coded <- function() {
  f <- c("output/validation_screening_to_code.xlsx", "output/validation_screening_to_code.csv")
  f <- f[file.exists(f)][1]
  if (is.na(f)) return(FALSE)
  ml <- "output/validation_ml_to_code.csv"
  file.exists(ml) && any(read.csv(ml)$ML_used_for_detection %in% c(0, 1))
}

t0 <- Sys.time()
for (i in seq_along(paths)) {
  if (i == 1 && !RUN_IMPORT) {
    cat("\n=== 01 import & merge: skipped (output/M_merged.rds exists) ===\n")
    next
  }
  if (SCRIPTS[i] == "08_validation.R" && !coded()) {
    cat("\n=== 08 validation: skipped (validation samples not coded yet;",
        "see validation/README.md) ===\n")
    next
  }
  cat(sprintf("\n=== %s %s ===\n", sub("_.*", "", SCRIPTS[i]), LABELS[i]))
  source(paths[i], echo = FALSE)
}

cat("\nPipeline finished in", round(difftime(Sys.time(), t0, units = "mins"), 1), "minutes\n")
cat("R", R.version$major, ".", R.version$minor, "| bibliometrix",
    as.character(packageVersion("bibliometrix")), "| dplyr", as.character(packageVersion("dplyr")), "\n")
writeLines(capture.output(sessionInfo()), "output/sessionInfo.txt")
