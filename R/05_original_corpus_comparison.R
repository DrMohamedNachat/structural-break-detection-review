# =============================================================================
# 05_original_corpus_comparison.R
# Comparison with the corpus of the first version of the search
#
# Purpose: document what the original search (1,796 records) captured and what
# the revised corpus adds.
#   1. Clean the original corpus with the criteria stated in the submitted
#      Table 1 (2010-2025, English), which had not been enforced.
#   2. Match it to the revised screened corpus (DOI, then normalised title)
#      and report the stratum of every original record.
#   3. Recall of the original search on the detection literature.
#   4. Exact ML/DL author-keyword counts in the original corpus.
#
# Input : merged_data.rds (original bibliometrix data frame, 1,796 records),
#         output/M_screened.rds, output/screening_flags.csv
# Output: output/tables/T11_*.csv
# =============================================================================

suppressMessages({ library(dplyr); library(tidyr) })
ORIGINAL_FILE <- "merged_data.rds"    # adjust the path if needed

O <- readRDS(ORIGINAL_FILE)
S <- readRDS("output/M_screened.rds")
FL <- read.csv("output/screening_flags.csv", stringsAsFactors = FALSE)

norm_doi_z <- function(x) {
  x <- tolower(trimws(as.character(x)))
  x <- sub("^https?://(dx\\.)?doi\\.org/", "", x)
  x <- gsub("[^a-z0-9]", "", x); x[x %in% c("", "na")] <- NA; x
}
norm_title <- function(x) {
  x <- toupper(as.character(x)); x <- gsub("[^A-Z0-9 ]", " ", x)
  x <- gsub("\\s+", " ", trimws(x)); x[x %in% c("", "NA")] <- NA; x
}

# ---- 1. Original corpus: enforce the stated criteria ---------------------------
O$PY <- as.numeric(O$PY)
tab1 <- data.frame(
  step = c("Original corpus as submitted", "Excluded: publication year 2026",
           "Excluded: language other than English", "Original corpus after correction"),
  n = c(nrow(O), sum(O$PY > 2025, na.rm = TRUE), sum(toupper(O$LA) != "ENGLISH" & !(O$PY > 2025)),
        sum(!(O$PY > 2025) & toupper(O$LA) == "ENGLISH")))
lang <- as.data.frame(table(language = O$LA[toupper(O$LA) != "ENGLISH"]))
print(tab1); print(lang)
write.csv(tab1, "output/tables/T11a_original_corpus_correction.csv", row.names = FALSE)
write.csv(lang, "output/tables/T11a2_original_non_english.csv", row.names = FALSE)
Oc <- O[!(O$PY > 2025) & toupper(O$LA) == "ENGLISH", ]

# ---- 2. Match to the revised corpus --------------------------------------------
Oc$doi_z <- norm_doi_z(Oc$DI); Oc$ti_n <- norm_title(Oc$TI)
FL$doi_z <- norm_doi_z(FL$DI);  FL$ti_n <- norm_title(FL$TI)
FL1 <- FL[!duplicated(FL$doi_z) | is.na(FL$doi_z), ]
i_doi <- match(Oc$doi_z, FL1$doi_z)
i_ti  <- match(Oc$ti_n,  FL$ti_n)
i <- ifelse(!is.na(i_doi), i_doi, i_ti)
Oc$found_in_extended_search <- !is.na(i)
Oc$match_type <- ifelse(!is.na(i_doi), "DOI", ifelse(!is.na(i_ti), "title", "not retrieved"))
Oc$tier_revised <- ifelse(is.na(i), NA, ifelse(!is.na(i_doi), FL1$tier[i_doi], FL$tier[i_ti]))
Oc$corpus_revised <- ifelse(is.na(i), NA, ifelse(!is.na(i_doi), FL1$CORPUS[i_doi], FL$CORPUS[i_ti]))

tab2 <- data.frame(
  indicator = c("Original records (corrected)", "Retrieved by the extended search", "  matched by DOI",
                "  matched by title only", "Not retrieved", "Retained by the revised screening",
                "  stratum T1a explicit detection", "  stratum T1b contextual detection",
                "  stratum T1c CUSUM stability diagnostic", "  stratum T2 regime-switching modelling",
                "  excluded by the revised screening"),
  n = c(nrow(Oc), sum(Oc$found_in_extended_search), sum(Oc$match_type == "DOI"),
        sum(Oc$match_type == "title"), sum(!Oc$found_in_extended_search),
        sum(Oc$tier_revised != "excluded", na.rm = TRUE),
        sum(Oc$tier_revised == "T1a_core_detection", na.rm = TRUE),
        sum(Oc$tier_revised == "T1b_contextual_detection", na.rm = TRUE),
        sum(Oc$tier_revised == "T1c_cusum_stability_diag", na.rm = TRUE),
        sum(Oc$tier_revised == "T2_regime_switching_modelling", na.rm = TRUE),
        sum(Oc$tier_revised == "excluded", na.rm = TRUE)))
tab2$share <- round(tab2$n / nrow(Oc), 3)
print(tab2); write.csv(tab2, "output/tables/T11b_original_vs_revised.csv", row.names = FALSE)
write.csv(Oc[, c("TI", "PY", "SO", "DI", "found_in_extended_search", "match_type", "tier_revised", "corpus_revised")],
          "output/tables/T11b2_original_records_mapping.csv", row.names = FALSE)

# ---- 3. Recall of the original search on the revised detection literature -----------
S$doi_z <- norm_doi_z(S$DI); S$ti_n <- norm_title(S$TI)
S$in_original <- (!is.na(S$doi_z) & S$doi_z %in% Oc$doi_z) | (!is.na(S$ti_n) & S$ti_n %in% Oc$ti_n)
tab3 <- S %>% group_by(CORPUS, tier) %>%
  summarise(revised = n(), in_original = sum(in_original),
            recall_of_original_search = round(in_original / revised, 3), .groups = "drop")
print(tab3); write.csv(tab3, "output/tables/T11c_recall_of_original_search.csv", row.names = FALSE)

# ---- 4. ML/DL author keywords in the original corpus (exact counts) -------------------
kw <- Oc %>% select(TI, DE) %>% filter(!is.na(DE), DE != "", DE != "NA") %>%
  mutate(kw = strsplit(DE, ";")) %>% unnest(kw) %>% mutate(kw = tolower(trimws(kw))) %>% filter(kw != "")
pats <- c("machine learning" = "^machine learning$", "deep learning" = "^deep learning$",
          "neural network(s)" = "neural network", "lstm" = "lstm", "random forest" = "random forest",
          "support vector / svm" = "support vector|^svm$", "artificial intelligence" = "^artificial intelligence$|^ai$",
          "reinforcement learning" = "reinforcement learning", "autoencoder" = "autoencoder",
          "concept drift" = "concept drift", "change point (any variant)" = "change[- ]?point",
          "structural break(s)" = "structural break", "regime switching (any variant)" = "regime[- ]?switch",
          "markov switching (any variant)" = "markov[- ]?switch")
tab4 <- data.frame(keyword = names(pats),
                   documents = sapply(pats, function(p) n_distinct(kw$TI[grepl(p, kw$kw)])),
                   row.names = NULL)
txt <- toupper(paste(Oc$TI, Oc$AB, Oc$DE))
ml_txt <- grepl("\\b(MACHINE LEARNING|DEEP LEARNING|NEURAL NETWORKS?|LSTM|RANDOM FORESTS?|SUPPORT VECTOR|AUTOENCODERS?|REINFORCEMENT LEARNING)", txt, perl = TRUE)
tab4 <- rbind(tab4, data.frame(keyword = "ML/DL mentioned in title, abstract or keywords", documents = sum(ml_txt)))
print(tab4); write.csv(tab4, "output/tables/T11d_original_ml_keyword_counts.csv", row.names = FALSE)
cat(sprintf("\nOriginal corpus (corrected, n = %d): %d documents (%.1f%%) mention ML/DL.\n",
            nrow(Oc), sum(ml_txt), 100 * mean(ml_txt)))
cat("Saved T11a-T11d\n")
