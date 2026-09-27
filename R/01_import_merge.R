# =============================================================================
# 01_import_merge.R
# Phase 1: import, deduplication, exclusion rules
#
# Input (all in the working directory, see section 1 to change locations):
#   Wos_A_*.txt     WoS plain-text exports, corpus A (Business & Economics)
#   WoS_B_*.txt     WoS plain-text exports, corpus B (all other areas)
#   Scopus_A.csv    Scopus CSV export, corpus A (ECON OR BUSI)
#   Scopus_B.csv    Scopus CSV export, corpus B (NOT ECON/BUSI)
#
# Output (folder output/):
#   M_merged.rds        merged, deduplicated corpus (bibliometrix data frame)
#                       with columns CORPUS (A/B) and SOURCE_DB (WoS/Scopus/Both)
#   W_wos.rds           WoS-only records after the same exclusions
#                       (for reference-based analyses, see note at the end)
#   prisma_counts.csv   counts at every step, for the PRISMA diagram
#   label_discordance.csv  papers classified A in one database and B in the other
#
# Tested with R 4.3.3 / bibliometrix 5.5.0 on the actual export files.
# =============================================================================

suppressMessages({
  library(bibliometrix)
  library(dplyr)
})

# ---- 0. Settings ------------------------------------------------------------
# Set the working directory to the folder containing the export files
# setwd("path/to/project")

YEAR_MAX <- 2025
dir.create("output", showWarnings = FALSE)

counts <- data.frame(step = character(), n = integer())
log_count <- function(step, n) {
  counts <<- rbind(counts, data.frame(step = step, n = n))
  cat(sprintf("%-60s %6d\n", step, n))
}

# Normalisation helpers used for deduplication
norm_doi <- function(x) {
  x <- tolower(trimws(as.character(x)))
  x <- sub("^https?://(dx\\.)?doi\\.org/", "", x)
  x[x %in% c("", "na")] <- NA
  x
}
norm_title <- function(x) {
  x <- toupper(as.character(x))
  x <- gsub("[^A-Z0-9 ]", " ", x)
  x <- gsub("\\s+", " ", trimws(x))
  x[x %in% c("", "NA")] <- NA
  x
}

# ---- 1. Import ----------------------------------------------------------------
# File locations. By default all files are in the working directory itself
# (e.g. Wos_A_01.txt ... Wos_A_13.txt, WoS_B_1.txt ... WoS_B_8.txt,
# Scopus_A.csv, Scopus_B.csv). Adjust the patterns / names if yours differ.
# ignore.case = TRUE, so "Wos_A" and "WoS_A" are both accepted.
wos_A_files <- list.files(".", pattern = "^wos_a_.*\\.txt$", ignore.case = TRUE, full.names = TRUE)
wos_B_files <- list.files(".", pattern = "^wos_b_.*\\.txt$", ignore.case = TRUE, full.names = TRUE)
scopus_A_file <- "Scopus_A.csv"
scopus_B_file <- "Scopus_B.csv"

# Stop early with a clear message if a file is missing
cat("Working directory:", getwd(), "\n")
cat("WoS A files found:", length(wos_A_files), "| WoS B files found:", length(wos_B_files), "\n")
if (length(wos_A_files) == 0 || length(wos_B_files) == 0)
  stop("No WoS files found: check the working directory and the file names.")
if (!file.exists(scopus_A_file) || !file.exists(scopus_B_file))
  stop("Scopus CSV files not found in the working directory.")

W_A <- convert2df(wos_A_files, dbsource = "wos", format = "plaintext"); W_A$CORPUS <- "A"
W_B <- convert2df(wos_B_files, dbsource = "wos", format = "plaintext"); W_B$CORPUS <- "B"
S_A <- convert2df(scopus_A_file, dbsource = "scopus", format = "csv"); S_A$CORPUS <- "A"
S_B <- convert2df(scopus_B_file, dbsource = "scopus", format = "csv"); S_B$CORPUS <- "B"

cat("\n===== Records identified =====\n")
log_count("WoS corpus A (imported)", nrow(W_A))
log_count("WoS corpus B (imported)", nrow(W_B))
log_count("Scopus corpus A", nrow(S_A))
log_count("Scopus corpus B", nrow(S_B))

# ---- 2. Deduplication (within and across databases) --------------------------
# All records are stacked with WoS first, so that when duplicates exist the WoS
# record is kept (it carries Web of Science Categories WC and Keywords Plus).
# Two records are duplicates if
#   (a) they share the same DOI, or
#   (b) they have the same normalised title, publication years differing by at
#       most one (early-access vs final year), and NOT two different DOIs.
# Rule (b) never merges two records that both have a DOI and whose DOIs differ
# (e.g. a conference version and a journal version with the same title).
W <- bind_rows(W_A, W_B); W$SRC <- "WoS"
S <- bind_rows(S_A, S_B); S$SRC <- "Scopus"
log_count("WoS records after import (convert2df drops exact UT duplicates)", nrow(W))
log_count("Scopus records after import", nrow(S))

X <- bind_rows(W, S)
X$doi_n <- norm_doi(X$DI)
X$ti_n  <- norm_title(X$TI)
X$py_n  <- suppressWarnings(as.numeric(X$PY))
X$doi_z   <- gsub("[^a-z0-9]", "", X$doi_n)                    # DOI without punctuation
X$doi_pre <- sub("[^.]*$", "", X$doi_n)                        # DOI prefix (venue/year)
X$doi_pre[is.na(X$doi_n) | X$doi_pre == ""] <- NA
X$so_n  <- gsub("[^A-Z0-9]", "", toupper(X$SO))
n <- nrow(X)
keep_of <- seq_len(n)              # index of the record each row is merged into
how     <- rep(NA_character_, n)   # "doi" or "title"

# (a) DOI
has_doi <- which(!is.na(X$doi_n))
first_doi <- match(X$doi_n[has_doi], X$doi_n[has_doi])
dup_a <- has_doi[has_doi[first_doi] != has_doi]
keep_of[dup_a] <- has_doi[first_doi][has_doi[first_doi] != has_doi]
how[dup_a] <- "doi"

# (b) title, among records not already merged by DOI
alive <- which(keep_of == seq_len(n) & !is.na(X$ti_n))
groups <- split(alive, X$ti_n[alive])
groups <- groups[lengths(groups) > 1]
for (g in groups) {
  kept <- integer(0)
  for (j in g) {                              # g is in priority order (WoS first)
    target <- NA_integer_
    for (k in kept) {
      same_year <- !is.na(X$py_n[j]) && !is.na(X$py_n[k]) &&
        abs(X$py_n[j] - X$py_n[k]) <= 1
      # same publication? DOIs equal (after removing punctuation, so that a
      # typo or a language variant does not split a record), or one missing,
      # or same source title, or same DOI prefix (same journal/conference)
      da <- X$doi_z[j]; db <- X$doi_z[k]
      doi_ok <- is.na(da) || is.na(db) || da == db ||
        X$so_n[j] == X$so_n[k] ||
        (!is.na(X$doi_pre[j]) && X$doi_pre[j] == X$doi_pre[k])
      if (same_year && doi_ok) { target <- k; how_j <- "title"; target <- k; break }
    }
    if (is.na(target)) kept <- c(kept, j) else { keep_of[j] <- target; how[j] <- "title" }
  }
}

removed <- which(keep_of != seq_len(n))
kind <- paste(X$SRC[removed], "->", X$SRC[keep_of[removed]])
cat("\n===== Duplicates removed =====\n")
log_count("Duplicates inside WoS", sum(kind == "WoS -> WoS"))
log_count("Duplicates inside Scopus", sum(kind == "Scopus -> Scopus"))
log_count("WoS-Scopus duplicates (WoS record kept)", sum(kind == "Scopus -> WoS"))
log_count("  matched by DOI",   sum(kind == "Scopus -> WoS" & how[removed] == "doi"))
log_count("  matched by title", sum(kind == "Scopus -> WoS" & how[removed] == "title"))

# Title matches NOT merged because the two DOIs differ (reported for transparency)
grp_all <- split(which(!is.na(X$ti_n)), X$ti_n[!is.na(X$ti_n)])
n_same_title_diff_doi <- sum(sapply(grp_all[lengths(grp_all) > 1], function(g) {
  d <- unique(na.omit(X$doi_n[g[keep_of[g] == g]])); max(0, length(d) - 1)
}))
log_count("Same title but different DOIs: kept as separate records", n_same_title_diff_doi)

# Source database and corpus-label discordance for kept records
cross <- removed[kind == "Scopus -> WoS"]
X$SOURCE_DB <- X$SRC
X$SOURCE_DB[unique(keep_of[cross])] <- "Both"
disc <- data.frame(
  TI = X$TI[keep_of[cross]], PY = X$PY[keep_of[cross]], SO = X$SO[keep_of[cross]],
  WoS_label = X$CORPUS[keep_of[cross]], Scopus_label = X$CORPUS[cross]
) %>% filter(WoS_label != Scopus_label) %>% distinct()
write.csv(disc, "output/label_discordance.csv", row.names = FALSE)
log_count("A/B label differs between databases (WoS label kept)", nrow(disc))

# Records sharing title and year that were NOT merged (different venue AND
# different DOI): typically a conference version and a journal version.
# They are listed so that an author can check them; they are kept as separate
# records unless the author decides otherwise.
alive2 <- which(keep_of == seq_len(n) & !is.na(X$ti_n))
gg <- split(alive2, paste(X$ti_n[alive2], X$py_n[alive2]))
gg <- gg[lengths(gg) > 1]
if (length(gg) > 0) {
  chk <- do.call(rbind, lapply(gg, function(k)
    data.frame(TI = X$TI[k], PY = X$PY[k], SO = X$SO[k], DI = X$DI[k], SRC = X$SRC[k])))
  write.csv(chk, "output/possible_duplicates_to_check.csv", row.names = FALSE)
}
log_count("Same title+year kept apart (manual check needed)", sum(lengths(gg)))

# Stable key for each record: normalised DOI, else title+year signature.
# It survives any renumbering of the screening IDs.
X$UID <- ifelse(!is.na(X$doi_z), paste0("doi:", X$doi_z),
                paste0("ti:", substr(X$ti_n, 1, 60), "|", X$py_n))

keep_rows <- which(keep_of == seq_len(n))
W_keep <- X[keep_rows[X$SRC[keep_rows] == "WoS"], ]
S_only <- X[keep_rows[X$SRC[keep_rows] == "Scopus"], ]
log_count("Scopus-only records added", nrow(S_only))

# ---- 4. Merge into one bibliometrix data frame --------------------------------
# remove.duplicated = FALSE because deduplication was done above, explicitly.
helper_cols <- c("doi_n", "ti_n", "py_n", "SRC", "doi_z", "doi_pre", "so_n")
W_keep <- W_keep[, setdiff(names(W_keep), helper_cols)]
S_only <- S_only[, setdiff(names(S_only), helper_cols)]
M <- mergeDbSources(W_keep, S_only, remove.duplicated = FALSE, verbose = FALSE)
log_count("Merged unique records (before exclusions)", nrow(M))

# ---- 5. Exclusion rules -----------------------------------------------------
M$PY <- as.numeric(M$PY)
excl_year <- !is.na(M$PY) & M$PY > YEAR_MAX
log_count(sprintf("Excluded: final publication year > %d", YEAR_MAX), sum(excl_year))
M <- M[!excl_year, ]

excl_retr <- grepl("RETRACTED", toupper(M$DT)) | grepl("^RETRACTED", toupper(M$TI))
log_count("Excluded: retracted publications", sum(excl_retr))
M <- M[!excl_retr, ]

log_count("Records retained after automatic exclusions", nrow(M))
log_count("  corpus A", sum(M$CORPUS == "A"))
log_count("  corpus B", sum(M$CORPUS == "B"))

cat("\nRecords by source database:\n"); print(table(M$SOURCE_DB, M$CORPUS))
cat("\nRecords by year:\n");            print(table(M$PY, M$CORPUS))

# ---- 6. WoS-only collection for reference-based analyses --------------------
# Each database writes cited references in its own format, so the same cited
# work cannot be matched reliably across WoS and Scopus. Recent bibliometrix
# versions empty the CR field of a merged collection for this reason.
# Co-citation / bibliographic coupling will therefore be run on WoS records only.
Wk <- W_keep[!(as.numeric(W_keep$PY) > YEAR_MAX) &
               !(grepl("RETRACTED", toupper(W_keep$DT)) | grepl("^RETRACTED", toupper(W_keep$TI))), ]
log_count("WoS records retained (for reference-based analyses)", nrow(Wk))

# ---- 7. Save ----------------------------------------------------------------
saveRDS(M,  "output/M_merged.rds")
saveRDS(Wk, "output/W_wos.rds")
write.csv(counts, "output/prisma_counts.csv", row.names = FALSE)

cat("\nSaved: output/M_merged.rds, output/W_wos.rds,",
    "output/prisma_counts.csv, output/label_discordance.csv\n")
cat("R", R.version$major, ".", R.version$minor,
    "| bibliometrix", as.character(packageVersion("bibliometrix")), "\n")
