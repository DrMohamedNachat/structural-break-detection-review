# =============================================================================
# 04_cross_citation.R
# Phase 4: do the two communities cite each other?
#
# Every WoS record lists its cited references (CR), most with a DOI. Matching
# those DOIs against the DOIs of the corpus documents gives the citation links
# INSIDE the corpus. We then measure:
#   - links A->A, A->B, B->A, B->B against a size-based and a time-aware benchmark;
#   - the share of papers citing at least one paper of the other corpus;
#   - whether detection papers of A cite the ML-tagged papers of the corpus;
#   - the evolution over time.
#
# Citing side : records indexed in WoS (SOURCE_DB WoS or Both), which carry CR.
#               The references are read from M_tagged.rds, where mergeDbSources
#               left them in CR_raw; W_wos.rds from 01_import_merge.R is used as
#               a fallback if that field is empty.
# Cited side  : every retained document with a DOI (WoS, Scopus or both).
#
# Input : output/M_tagged.rds (03), optionally output/W_wos.rds (01)
# Output: output/tables/T10_*.csv, output/figures/F10_*.png|pdf
# =============================================================================

suppressMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

M <- readRDS("output/M_tagged.rds")
# After mergeDbSources, bibliometrix leaves the processed CR field unusable and
# keeps the raw WoS reference string in CR_raw.
if ("CR_raw" %in% names(M)) M$CR <- M$CR_raw
norm_doi <- function(x) {
  x <- tolower(trimws(as.character(x)))
  x <- sub("^https?://(dx\\.)?doi\\.org/", "", x)
  x <- sub("[\\.,;\\]\\)]+$", "", x)
  x[x %in% c("", "na")] <- NA
  x
}
wilson <- function(x, n, z = 1.96) {
  p <- x / n; den <- 1 + z^2 / n
  data.frame(share = p,
             lo = pmax(0, (p + z^2 / (2 * n)) / den - z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / den),
             hi = pmin(1, (p + z^2 / (2 * n)) / den + z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / den))
}

# ---- 1. Cited side ------------------------------------------------------------------
M$doi_n <- norm_doi(M$DI)
cited_tab <- M %>% filter(!is.na(doi_n)) %>% distinct(doi_n, .keep_all = TRUE) %>%
  transmute(doi_n, cited_corpus = CORPUS, cited_stratum = stratum, cited_PY = PY,
            cited_ML = `Machine / deep learning`, cited_MS = `Markov / regime switching`)

# ---- 2. Citing side -----------------------------------------------------------------
cr_ok <- !is.na(M$CR) & nchar(M$CR) > 0
if (sum(cr_ok & M$SOURCE_DB %in% c("WoS", "Both")) < 100 && file.exists("output/W_wos.rds")) {
  W <- readRDS("output/W_wos.rds")
  M$CR <- W$CR[match(M$UT, W$UT)]
  cr_ok <- !is.na(M$CR) & nchar(M$CR) > 0
}
citing <- M %>% filter(SOURCE_DB %in% c("WoS", "Both"), cr_ok) %>%
  select(UID, CORPUS, stratum, PY, citing_ML = `Machine / deep learning`, doi_self = doi_n, CR)

refs <- citing %>% mutate(ref = strsplit(CR, ";")) %>% select(-CR) %>% unnest(ref) %>%
  mutate(ref = trimws(ref))
n_refs <- nrow(refs)
refs$doi_r <- ifelse(grepl("\\bDOI\\b", refs$ref), sub(".*\\bDOI\\s+\\[?", "", refs$ref), NA)
refs$doi_r <- norm_doi(sub("[, ].*$", "", refs$doi_r))
cov_doi <- mean(!is.na(refs$doi_r))

links <- refs %>% filter(!is.na(doi_r), is.na(doi_self) | doi_r != doi_self) %>%
  inner_join(cited_tab, by = c("doi_r" = "doi_n")) %>% distinct(UID, doi_r, .keep_all = TRUE)

coverage <- data.frame(
  indicator = c("Citing WoS records", "Cited references", "Share of references with a DOI",
                "Corpus documents with a DOI (citable)", "Citation links inside the corpus"),
  value = c(nrow(citing), n_refs, round(cov_doi, 3), nrow(cited_tab), nrow(links)))
write.csv(coverage, "output/tables/T10a_coverage.csv", row.names = FALSE); print(coverage)

# ---- 3. Link matrix, size-based and time-aware benchmarks -------------------------------
mat <- links %>% count(citing_corpus = CORPUS, cited_corpus, name = "links") %>%
  group_by(citing_corpus) %>% mutate(share_of_citing_links = links / sum(links)) %>% ungroup()
citable_share <- cited_tab %>% count(cited_corpus, name = "citable") %>%
  mutate(citable_share = citable / sum(citable))
mat <- mat %>% left_join(citable_share, by = "cited_corpus") %>%
  mutate(ratio_to_benchmark = share_of_citing_links / citable_share)
cum_B <- cited_tab %>% count(cited_PY, cited_corpus) %>%
  pivot_wider(names_from = cited_corpus, values_from = n, values_fill = 0) %>%
  arrange(cited_PY) %>% mutate(share_B_cum = cumsum(B) / (cumsum(A) + cumsum(B)))
exp_tw <- links %>% left_join(cum_B %>% select(cited_PY, share_B_cum), by = c("PY" = "cited_PY")) %>%
  group_by(citing_corpus = CORPUS) %>%
  summarise(expected_share_B_time_aware = mean(share_B_cum, na.rm = TRUE), .groups = "drop")
mat <- mat %>% left_join(exp_tw, by = "citing_corpus") %>%
  mutate(expected_time_aware = ifelse(cited_corpus == "B", expected_share_B_time_aware,
                                      1 - expected_share_B_time_aware),
         ratio_time_aware = share_of_citing_links / expected_time_aware) %>%
  select(-expected_share_B_time_aware)
write.csv(mat, "output/tables/T10b_link_matrix.csv", row.names = FALSE)
cat("\nCitation links inside the corpus:\n")
print(mat %>% mutate(across(where(is.numeric), ~ round(.x, 3))) %>% as.data.frame())

# Same matrix by stratum of the citing paper (detection vs modelling)
mat_s <- links %>% count(citing_stratum = stratum, citing_corpus = CORPUS, cited_corpus, name = "links") %>%
  group_by(citing_stratum, citing_corpus) %>% mutate(share = round(links / sum(links), 3)) %>% ungroup()
write.csv(mat_s, "output/tables/T10b2_link_matrix_by_stratum.csv", row.names = FALSE)

# ---- 4. Paper level ------------------------------------------------------------------
paper <- citing %>% select(UID, CORPUS, stratum, PY, citing_ML) %>%
  left_join(links %>% group_by(UID) %>%
              summarise(any_local = TRUE, cites_A = any(cited_corpus == "A"),
                        cites_B = any(cited_corpus == "B"), cites_ML = any(cited_ML), .groups = "drop"),
            by = "UID") %>%
  mutate(across(c(any_local, cites_A, cites_B, cites_ML), ~ coalesce(.x, FALSE)))
paper_tab <- paper %>% filter(any_local) %>% group_by(CORPUS, stratum) %>%
  summarise(papers_with_local_citations = n(),
            pct_citing_A = round(100 * mean(cites_A), 1), pct_citing_B = round(100 * mean(cites_B), 1),
            pct_citing_ML = round(100 * mean(cites_ML), 1), .groups = "drop")
write.csv(paper_tab, "output/tables/T10c_paper_level.csv", row.names = FALSE)
cat("\nAmong papers citing at least one corpus document:\n"); print(paper_tab)

# ---- 5. Links to ML-tagged papers ---------------------------------------------------
ml_links <- links %>% filter(cited_ML) %>%
  count(citing_corpus = CORPUS, citing_stratum = stratum, cited_corpus, name = "links_to_ML_papers")
ml_citable <- cited_tab %>% filter(cited_ML) %>% count(cited_corpus, name = "ML_papers_citable")
write.csv(ml_links %>% left_join(ml_citable, by = "cited_corpus"),
          "output/tables/T10d_links_to_ML_papers.csv", row.names = FALSE)
cat("\nLinks pointing to ML-tagged papers:\n"); print(ml_links)

# ---- 6. Over time ---------------------------------------------------------------------
links$period <- cut(links$PY, c(2009, 2014, 2019, 2022, 2025),
                    labels = c("2010-2014", "2015-2019", "2020-2022", "2023-2025"))
cross_time <- links %>% group_by(citing_corpus = CORPUS, period) %>%
  summarise(links = n(), to_other = sum(cited_corpus != CORPUS), .groups = "drop") %>%
  bind_cols(wilson(.$to_other, .$links))
write.csv(cross_time, "output/tables/T10e_cross_links_over_time.csv", row.names = FALSE)
cat("\nShare of links going to the OTHER corpus, by period:\n"); print(cross_time)

p <- ggplot(cross_time, aes(period, 100 * share, colour = citing_corpus, group = citing_corpus)) +
  geom_line(linewidth = 0.8) + geom_point(size = 2) +
  geom_errorbar(aes(ymin = 100 * lo, ymax = 100 * hi), width = 0.1) +
  scale_colour_manual(values = c(A = "#1f4e79", B = "#c55a11"),
                      labels = c(A = "A citing B", B = "B citing A"), name = NULL) +
  labs(x = "Period of the citing paper", y = "Within-corpus links to the other corpus (%)") +
  theme_minimal(base_size = 11) + theme(legend.position = "bottom")
ggsave("output/figures/F10_cross_citation_over_time.png", p, width = 6.5, height = 4.2, dpi = 300)
ggsave("output/figures/F10_cross_citation_over_time.pdf", p, width = 6.5, height = 4.2)
cat("\nSaved T10a-T10e and F10\n")
