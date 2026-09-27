# =============================================================================
# 09_screening_candidates.R
# Candidate set for the title/abstract screening of the systematic-review part
#
# The systematic review (Section 4) targets studies that PROPOSE or EVALUATE a
# method for detecting structural breaks / change points / regime changes in
# financial or economic time series.
#
# Candidates = records of the filtered corpus that satisfy BOTH
#   (i)  detection focus: a break/change-point/regime term in the TITLE or
#        AUTHOR KEYWORDS (not only in the abstract, where it is often incidental);
#   (ii) methodological signal in the ABSTRACT: proposal of a method, simulation
#        or Monte Carlo evidence, finite-sample/size-power results, comparison
#        of performance, detection delay / false alarms, asymptotic theory;
# and NOT primarily about derivative pricing or stochastic control under an
# assumed regime process (regime switching as a modelling device, not detected).
#
# Output:
#   output/screening/screening_candidates.csv   all candidates, one row each
#   output/screening/double_coding_sample.csv   200 random candidates for blind
#                                               coding by two authors
# Tested with R 4.3.3 / bibliometrix 5.5.0 on the actual data.
# =============================================================================

suppressMessages(library(dplyr))
dir.create("output/screening", showWarnings = FALSE, recursive = TRUE)

M <- readRDS("output/M_tagged.rds")
ti_de <- toupper(paste(M$TI, M$DE))
ab    <- toupper(M$AB)

focus <- paste0(
  "CHANGE[- ]?POINT|STRUCTURAL BREAK|STRUCTURAL CHANGE|STRUCTURAL INSTABILIT|",
  "PARAMETER INSTABILIT|BREAK[- ]?POINT|BREAK DATE|TREND BREAK|",
  "REGIME (CHANGE|SHIFT|SWITCH|DETECTION|IDENTIFICATION)|MARKOV[- ]SWITCH|HIDDEN MARKOV|",
  "CHANGE DETECTION|CONCEPT DRIFT|SEGMENTATION|BUBBLE|CUSUM|BAI[- ]PERRON|CHOW TEST")
method <- paste0(
  "WE PROPOSE|WE DEVELOP|WE INTRODUCE|THIS PAPER PROPOSES|THIS STUDY PROPOSES|",
  "IS PROPOSED|ARE PROPOSED|",
  "NEW (TEST|METHOD|APPROACH|PROCEDURE|ALGORITHM|ESTIMATOR|STATISTIC|FRAMEWORK|DETECTOR)|",
  "MONTE CARLO|SIMULATION STUD|SIMULATED DATA|FINITE[- ]SAMPLE|SIZE AND POWER|",
  "EMPIRICAL (SIZE|POWER)|OUTPERFORM|COMPARE THE PERFORMANCE|DETECTION DELAY|",
  "FALSE ALARM|ASYMPTOTIC (DISTRIBUTION|PROPERTIES|THEORY)|CONSISTEN(T|CY) (OF|ESTIMATOR)")
nondet <- paste0(
  "OPTION PRICING|OPTIMAL (INVESTMENT|DIVIDEND|CONSUMPTION|PORTFOLIO|STOPPING|CONTROL)|",
  "STOCHASTIC CONTROL|INSURER|REINSURANCE|ESSCHER|HAMILTON-JACOBI|HJB|MEAN-VARIANCE|VALUATION OF")

is_focus  <- grepl(focus,  ti_de, perl = TRUE)
is_method <- grepl(method, ab,    perl = TRUE)
is_nondet <- grepl(nondet, ti_de, perl = TRUE)
cand <- is_focus & is_method & !is_nondet

cat("Detection focus (title/keywords):", sum(is_focus), "\n")
cat("  + methodological signal:        ", sum(is_focus & is_method), "\n")
cat("  - pricing/control topics:       ", sum(is_focus & is_method & is_nondet), "\n")
cat("Screening candidates:             ", sum(cand), "\n")

C <- M[cand, ] %>%
  arrange(CORPUS, PY, TI) %>%
  transmute(ID = sprintf("S%04d", row_number()), UID, CORPUS, PY, SO, TI, AB, DE, DI,
            SOURCE_DB, TC)
# UID is a stable key (normalised DOI, else title+year signature): screening
# IDs are renumbered whenever the corpus changes, UID is not.
write.csv(C, "output/screening/screening_candidates.csv", row.names = FALSE)

# Map the IDs of the previous candidate file (before the deduplication fix)
# onto the new UIDs, so that codes already produced remain usable.
old_path <- "output/screening/screening_candidates_v1.csv"
if (file.exists(old_path)) {
  old <- read.csv(old_path, stringsAsFactors = FALSE)
  # same normalisation as in 01_import_merge.R (spaces are kept)
  nz <- function(x) { y <- gsub("[^A-Z0-9 ]", " ", toupper(x)); trimws(gsub("\\s+", " ", y)) }
  old$UID <- ifelse(!is.na(old$DI) & old$DI != "",
                    paste0("doi:", tolower(gsub("[^a-zA-Z0-9]", "", old$DI))),
                    paste0("ti:", substr(nz(old$TI), 1, 60), "|", old$PY))
  map <- old %>% select(old_ID = ID, UID) %>%
    left_join(C %>% select(new_ID = ID, UID), by = "UID")
  write.csv(map, "output/screening/id_map_v1_to_v2.csv", row.names = FALSE)
  cat("ID map written; old IDs without a match in the new file:",
      sum(is.na(map$new_ID)), "\n")
}

# Blind double-coding sample: 200 random candidates, no corpus label
set.seed(2027)
S <- C[sample(nrow(C), 200), ] %>%
  transmute(ID, PY, SO, TI, AB,
            coder1_code = "", coder1_family = "",
            coder2_code = "", coder2_family = "")
write.csv(S, "output/screening/double_coding_sample.csv", row.names = FALSE)

cat("\nSaved output/screening/screening_candidates.csv (", nrow(C), "records)\n")
cat("Saved output/screening/double_coding_sample.csv (200 records)\n")
