# =============================================================================
# 03_bibliometric_analysis.R
# Phase 3: bibliometric analyses on the screened corpus
#
# Input : output/M_screened.rds   (from 02b_screening.R; carries CORPUS and tier)
# Output: output/tables/*.csv, output/figures/*.png|pdf, output/vosviewer/*,
#         output/M_tagged.rds (used by 04_cross_citation.R)
#
# Contents
#   1. Main information (Table 2): A, B, A+B, and detection vs modelling strata
#   2. Annual production by corpus and by stratum (+ figures)
#   3. Top sources; top countries (corresponding author, SCP/MCP)
#   4. Most cited documents: all, and detection strata only
#   5. Author keywords (normalised + synonym table), counts and shares by
#      corpus; exact counts of ML/DL keywords
#   6. Method-family prevalence with 95% Wilson CIs, by corpus and by
#      stratum x period; ML/DL share per year among DETECTION papers
#   7. Sensitivity: records retrieved WITHOUT regime-switching terms
#   8. Keyword co-occurrence network exported in VOSviewer map/network format
#      (author keywords, detection strata and full corpus)
#   9. Three-field plot (countries - keywords - sources), saved as HTML
#
# Family / ML tagging is lexical: it measures whether a family is MENTIONED
# in title, abstract or author keywords, not whether it is the method used.
# The ML tag is validated by hand in output/validation_ml_to_code.csv (02b).
#
# Tested with R 4.3.3 / bibliometrix 5.x on output/M_screened.rds.
# =============================================================================

suppressMessages({
  library(bibliometrix)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

dir.create("output/tables",    showWarnings = FALSE, recursive = TRUE)
dir.create("output/figures",   showWarnings = FALSE, recursive = TRUE)
dir.create("output/vosviewer", showWarnings = FALSE, recursive = TRUE)

M <- readRDS("output/M_screened.rds")
M$PY <- as.numeric(M$PY)
M$TC <- suppressWarnings(as.numeric(M$TC))
M$stratum <- ifelse(M$tier == "T2_regime_switching_modelling", "T2 modelling", "T1 detection")
corp_lab <- c(A = "A: economics & business venues", B = "B: statistics, CS & other venues")
cols_ab  <- c(A = "#1f4e79", B = "#c55a11")

save_tab <- function(x, name) write.csv(x, file.path("output/tables", name), row.names = FALSE)
save_fig <- function(p, name, w = 7, h = 4.5) {
  ggsave(file.path("output/figures", paste0(name, ".png")), p, width = w, height = h, dpi = 300)
  ggsave(file.path("output/figures", paste0(name, ".pdf")), p, width = w, height = h)
}
wilson <- function(x, n, z = 1.96) {
  p <- x / n; den <- 1 + z^2 / n
  centre <- (p + z^2 / (2 * n)) / den
  half <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / den
  data.frame(share = p, lo = pmax(0, centre - half), hi = pmin(1, centre + half))
}

# ---- 1. Main information ---------------------------------------------------------
main_info <- function(D, label) {
  r <- biblioAnalysis(D, sep = ";")
  s <- summary(r, k = 10, verbose = FALSE)
  mi <- s$MainInformationDF
  names(mi) <- c("Description", label)
  mi
}
tab_main <- main_info(M, "A+B") %>%
  left_join(main_info(M[M$CORPUS == "A", ], "A"), by = "Description") %>%
  left_join(main_info(M[M$CORPUS == "B", ], "B"), by = "Description") %>%
  left_join(main_info(M[M$stratum == "T1 detection", ], "T1 detection"), by = "Description") %>%
  left_join(main_info(M[M$stratum == "T2 modelling", ], "T2 modelling"), by = "Description")
save_tab(tab_main, "T1_main_information.csv")
cat("Main information saved\n")

# ---- 2. Annual production -----------------------------------------------------------
prod <- M %>% count(CORPUS, PY, name = "n") %>% arrange(CORPUS, PY)
save_tab(prod, "T2_annual_production.csv")
p_prod <- ggplot(prod, aes(PY, n, colour = CORPUS)) +
  geom_line(linewidth = 0.8) + geom_point(size = 1.6) +
  scale_colour_manual(values = cols_ab, labels = corp_lab, name = NULL) +
  scale_x_continuous(breaks = seq(2010, 2025, 3)) +
  labs(x = "Publication year", y = "Documents") +
  theme_minimal(base_size = 11) + theme(legend.position = "bottom")
save_fig(p_prod, "F2_annual_production")

prod_s <- M %>% count(stratum, CORPUS, PY, name = "n")
save_tab(prod_s, "T2c_annual_production_by_stratum.csv")
p_prod_s <- ggplot(prod_s, aes(PY, n, colour = CORPUS, linetype = stratum)) +
  geom_line(linewidth = 0.8) +
  scale_colour_manual(values = cols_ab, labels = corp_lab, name = NULL) +
  scale_linetype_manual(values = c("T1 detection" = "solid", "T2 modelling" = "dashed"), name = NULL) +
  scale_x_continuous(breaks = seq(2010, 2025, 3)) +
  labs(x = "Publication year", y = "Documents") +
  theme_minimal(base_size = 11) + theme(legend.position = "bottom", legend.box = "vertical")
save_fig(p_prod_s, "F2b_annual_production_by_stratum", h = 5)

cagr <- prod %>% group_by(CORPUS) %>%
  summarise(n2010 = n[PY == 2010], n2025 = n[PY == 2025],
            CAGR_pct = 100 * ((n2025 / n2010)^(1 / 15) - 1), .groups = "drop")
save_tab(cagr, "T2b_growth.csv"); print(cagr)

# ---- 3. Sources and countries ---------------------------------------------------------
top_sources <- M %>% count(CORPUS, SO, name = "n") %>%
  group_by(CORPUS) %>% mutate(share = round(n / sum(n), 4)) %>%
  slice_max(n, n = 15, with_ties = FALSE) %>% ungroup()
save_tab(top_sources, "T3_top_sources.csv")

top_sources_det <- M %>% filter(stratum == "T1 detection") %>% count(CORPUS, SO, name = "n") %>%
  group_by(CORPUS) %>% slice_max(n, n = 15, with_ties = FALSE) %>% ungroup()
save_tab(top_sources_det, "T3b_top_sources_detection_only.csv")

# Corresponding-author country with single- vs multiple-country publications,
# as in the submitted Table 4 (bibliometrix CountryCollaboration)
country_tab <- function(D, label) {
  r <- biblioAnalysis(D, sep = ";")
  cc <- r$CountryCollaboration
  if (is.null(cc)) return(NULL)
  D2 <- metaTagExtraction(D, Field = "AU1_CO", sep = ";")
  cit <- D2 %>% filter(!is.na(AU1_CO), AU1_CO != "NA") %>%
    group_by(Country = AU1_CO) %>%
    summarise(total_citations = sum(TC, na.rm = TRUE), mean_citations = round(mean(TC, na.rm = TRUE), 2),
              .groups = "drop")
  cc %>% mutate(Articles = SCP + MCP, MCP_ratio = round(MCP / Articles, 3)) %>%
    left_join(cit, by = "Country") %>% arrange(desc(Articles)) %>%
    slice_head(n = 15) %>% mutate(CORPUS = label)
}
countries <- bind_rows(country_tab(M, "A+B"), country_tab(M[M$CORPUS == "A", ], "A"),
                       country_tab(M[M$CORPUS == "B", ], "B"))
save_tab(countries, "T4_top_countries_corresponding_author.csv")

# ---- 3b. Authors, world map and collaboration heatmap (Figures 3-5 of the paper) ----
# Top 15 most productive authors (bar chart + table)
res_all <- biblioAnalysis(M, sep = ";")
top_auth <- data.frame(author = names(res_all$Authors), articles = as.integer(res_all$Authors),
                       stringsAsFactors = FALSE)[1:15, ]
top_auth$fractionalised <- round(as.numeric(res_all$AuthorsFrac$Frequency[match(top_auth$author, res_all$AuthorsFrac$Author)]), 2)
save_tab(top_auth, "T3c_top_authors.csv")
p_auth <- ggplot(top_auth, aes(x = reorder(author, articles), y = articles)) +
  geom_col(fill = "#c55a11", width = 0.7) +
  geom_text(aes(label = articles), hjust = -0.2, size = 3) +
  coord_flip() + labs(x = NULL, y = "Number of articles") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
  theme_minimal(base_size = 11)
save_fig(p_auth, "F3_top_authors", w = 6.5, h = 5)

# Country statistics from ALL author affiliations (AU_CO), as in the submitted Figure 4
Mco <- metaTagExtraction(M, Field = "AU_CO", sep = ";")
Mco$RID2 <- seq_len(nrow(Mco))
co_long <- Mco %>% select(RID = RID2, AU_CO, TC) %>%
  filter(!is.na(AU_CO), AU_CO != "NA") %>%
  mutate(country = strsplit(AU_CO, ";")) %>% unnest(country) %>%
  mutate(country = trimws(country)) %>% filter(country != "") %>% distinct(RID, country, TC)
co_stats <- co_long %>% group_by(country) %>%
  summarise(publications = n(), total_citations = sum(TC, na.rm = TRUE), .groups = "drop") %>%
  arrange(desc(publications))
save_tab(co_stats, "T4b_countries_all_affiliations.csv")

# World bubble map: bubble size = publications, colour = total citations
map_ok <- tryCatch({
  if (!requireNamespace("maps", quietly = TRUE)) stop("package 'maps' not installed: install.packages('maps')")
  world <- ggplot2::map_data("world")
  # bibliometrix country names -> maps region names (extend if a country is missing)
  fix <- c("USA" = "USA", "UNITED STATES" = "USA", "UNITED KINGDOM" = "UK", "KOREA" = "South Korea",
           "SOUTH KOREA" = "South Korea", "RUSSIA" = "Russia", "RUSSIAN FEDERATION" = "Russia",
           "CZECH REPUBLIC" = "Czech Republic", "IRAN" = "Iran", "VIET NAM" = "Vietnam", "VIETNAM" = "Vietnam",
           "TURKEY" = "Turkey", "TURKIYE" = "Turkey", "HONG KONG" = "China", "TAIWAN" = "Taiwan",
           "UNITED ARAB EMIRATES" = "United Arab Emirates", "SAUDI ARABIA" = "Saudi Arabia",
           "NEW ZEALAND" = "New Zealand", "SOUTH AFRICA" = "South Africa", "NORTH MACEDONIA" = "North Macedonia",
           "BOSNIA AND HERZEGOVINA" = "Bosnia and Herzegovina", "TRINIDAD AND TOBAGO" = "Trinidad",
           "BRUNEI DARUSSALAM" = "Brunei", "SYRIAN ARAB REPUBLIC" = "Syria", "CÔTE D'IVOIRE" = "Ivory Coast",
           "COTE D'IVOIRE" = "Ivory Coast", "REPUBLIC OF KOREA" = "South Korea", "SLOVAKIA" = "Slovakia",
           "MACEDONIA" = "North Macedonia", "PEOPLES R CHINA" = "China", "ENGLAND" = "UK", "SCOTLAND" = "UK",
           "WALES" = "UK", "NORTH IRELAND" = "UK", "U ARAB EMIRATES" = "United Arab Emirates")
  to_title <- function(x) { x <- tolower(x); gsub("(^|\\s)(\\w)", "\\1\\U\\2", x, perl = TRUE) }
  co_stats$region <- ifelse(co_stats$country %in% names(fix), fix[co_stats$country], to_title(co_stats$country))
  co_stats$region[co_stats$region == "Usa"] <- "USA"; co_stats$region[co_stats$region == "Uk"] <- "UK"
  centroids <- world %>% group_by(region) %>% summarise(long = mean(range(long)), lat = mean(range(lat)), .groups = "drop")
  centroids$long[centroids$region == "USA"] <- -98; centroids$lat[centroids$region == "USA"] <- 39
  centroids$long[centroids$region == "Russia"] <- 60; centroids$lat[centroids$region == "Russia"] <- 60
  centroids$long[centroids$region == "France"] <- 2.5; centroids$lat[centroids$region == "France"] <- 46.5
  centroids$long[centroids$region == "UK"] <- -2; centroids$lat[centroids$region == "UK"] <- 54
  pts <- co_stats %>% inner_join(centroids, by = "region")
  missing <- setdiff(co_stats$region, centroids$region)
  if (length(missing)) message("Countries not matched to the map (add to 'fix'): ", paste(missing, collapse = ", "))
  p_map <- ggplot() +
    geom_polygon(data = world %>% filter(region != "Antarctica"), aes(long, lat, group = group),
                 fill = "grey88", colour = "white", linewidth = 0.15) +
    geom_point(data = pts %>% arrange(desc(publications)),
               aes(long, lat, size = publications, colour = total_citations), alpha = 0.85) +
    { if (requireNamespace("ggrepel", quietly = TRUE))
        ggrepel::geom_text_repel(data = pts %>% slice_max(publications, n = 15),
                                 aes(long, lat, label = region), size = 2.8, min.segment.length = 0.2,
                                 max.overlaps = 30)
      else geom_text(data = pts %>% slice_max(publications, n = 15), aes(long, lat, label = region),
                     size = 2.8, vjust = -1.6) } +
    scale_size_area(max_size = 16, name = "Publications") +
    scale_colour_gradient(low = "#bfe0d8", high = "#1f3b73", name = "Citations", trans = "sqrt") +
    coord_quickmap(ylim = c(-55, 80)) + theme_void(base_size = 11) +
    theme(legend.position = "right")
  save_fig(p_map, "F4_world_map", w = 10, h = 5.2)
  TRUE
}, error = function(e) { message("World map skipped: ", conditionMessage(e)); FALSE })

# Country collaboration heatmap (number of co-authored papers between country pairs)
collab_ok <- tryCatch({
  NetCo <- biblioNetwork(Mco, analysis = "collaboration", network = "countries", sep = ";")
  Mx <- as.matrix(NetCo); diag(Mx) <- 0
  top <- names(sort(rowSums(Mx), decreasing = TRUE))[1:20]
  Mx <- Mx[top, top]
  hm <- as.data.frame(as.table(Mx)); names(hm) <- c("from", "to", "papers")
  hm <- hm %>% filter(papers > 0) %>%
    mutate(from = factor(from, levels = rev(top)), to = factor(to, levels = top))
  save_tab(hm, "T4c_country_collaboration_top20.csv")
  p_hm <- ggplot(hm, aes(to, from, fill = papers)) +
    geom_tile(colour = "white") +
    geom_text(aes(label = papers), size = 2.6, colour = ifelse(hm$papers > max(hm$papers) / 2, "white", "black")) +
    scale_fill_gradient(low = "#dbe7f3", high = "#1f4e79", name = "Co-authored\npapers") +
    labs(x = NULL, y = NULL) + theme_minimal(base_size = 10) +
    theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5), panel.grid = element_blank())
  save_fig(p_hm, "F5_country_collaboration_heatmap", w = 8, h = 7)
  TRUE
}, error = function(e) { message("Collaboration heatmap skipped: ", conditionMessage(e)); FALSE })

# ---- 4. Most cited documents -----------------------------------------------------------
# TC is taken from the database of the retained record (WoS if indexed there).
top_cited <- M %>% group_by(CORPUS) %>% slice_max(TC, n = 20, with_ties = FALSE) %>% ungroup() %>%
  transmute(CORPUS, stratum, first_author = sub(";.*", "", AU), PY, TI, SO, TC,
            TC_per_year = round(TC / (2026 - PY), 2), DI, SOURCE_DB)
save_tab(top_cited, "T5_top_cited.csv")
top_cited_det <- M %>% filter(stratum == "T1 detection") %>%
  slice_max(TC, n = 20, with_ties = FALSE) %>%
  transmute(CORPUS, first_author = sub(";.*", "", AU), PY, TI, SO, TC,
            TC_per_year = round(TC / (2026 - PY), 2), DI, ML_vocab)
save_tab(top_cited_det, "T5b_top_cited_detection_only.csv")

# ---- 5. Author keywords ---------------------------------------------------------------
# Synonym table (also released as data/keyword_synonyms.csv): extend it if new
# variants appear in T6. The thesaurus is applied here rather than in VOSviewer.
kw_synonyms <- c(
  "regime-switching" = "regime switching", "regime switching model" = "regime switching",
  "regime switching models" = "regime switching", "regime-switching model" = "regime switching",
  "markov regime switching" = "markov switching", "markov regime-switching" = "markov switching",
  "markov-switching" = "markov switching", "markov switching model" = "markov switching",
  "markov-switching model" = "markov switching", "markov regime-switching model" = "markov switching",
  "structural change" = "structural break", "structural changes" = "structural break",
  "structural breaks" = "structural break", "change-point" = "change point", "changepoint" = "change point",
  "change points" = "change point", "change-points" = "change point", "changepoints" = "change point",
  "change point detection" = "change point", "change-point detection" = "change point",
  "changepoint detection" = "change point",
  "neural networks" = "neural network", "artificial neural network" = "neural network",
  "artificial neural networks" = "neural network", "deep neural network" = "deep learning",
  "deep neural networks" = "deep learning", "long short-term memory" = "lstm", "long short term memory" = "lstm",
  "lstm network" = "lstm", "lstm networks" = "lstm", "random forests" = "random forest",
  "support vector machine" = "svm", "support vector machines" = "svm", "support vector regression" = "svm",
  "garch model" = "garch", "garch models" = "garch", "cusum test" = "cusum",
  "bai-perron" = "bai perron", "bai and perron" = "bai perron", "bai–perron" = "bai perron",
  "stock markets" = "stock market", "exchange rates" = "exchange rate", "oil prices" = "oil price",
  "stock returns" = "stock return", "interest rates" = "interest rate", "financial markets" = "financial market",
  "multiple structural breaks" = "structural break", "unit root test" = "unit root", "unit root tests" = "unit root",
  "hidden markov models" = "hidden markov model", "cryptocurrencies" = "cryptocurrency",
  "co-integration" = "cointegration", "unit roots" = "unit root", "unit-root" = "unit root",
  "business cycles" = "business cycle", "regime shifts" = "regime shift", "regime switch" = "regime switching",
  "regime-switching models" = "regime switching", "regime switching models" = "regime switching",
  "markov switching models" = "markov switching", "markov-switching models" = "markov switching",
  "markov-switching garch" = "ms-garch", "markov switching garch" = "ms-garch",
  "stock prices" = "stock price", "asymmetries" = "asymmetry", "nonlinearities" = "nonlinearity",
  "non-linearity" = "nonlinearity", "non-linear" = "nonlinear", "volatility spillovers" = "volatility spillover",
  "spillover effects" = "spillover effect", "spillovers" = "spillover", "real exchange rates" = "real exchange rate",
  "crude oil prices" = "crude oil price", "commodity markets" = "commodity market", "commodities" = "commodity",
  "breakpoints" = "breakpoint", "trend breaks" = "trend break", "structural shifts" = "structural shift",
  "covid-19 pandemic" = "covid-19", "covid19" = "covid-19", "coronavirus" = "covid-19",
  "bai-perron test" = "bai perron", "icss algorithm" = "icss", "cusum test" = "cusum",
  "chow test" = "chow test", "zivot-andrews" = "zivot andrews", "zivot-andrews test" = "zivot andrews",
  "vector error correction model" = "vecm", "autoregressive distributed lag" = "ardl",
  "autoregressive distributed lag model" = "ardl", "non-linear ardl" = "nardl", "nonlinear ardl" = "nardl",
  "purchasing power parity" = "ppp", "efficient market hypothesis" = "market efficiency",
  "economic policy uncertainty" = "policy uncertainty", "global financial crisis" = "financial crisis"
)
norm_kw <- function(k) {
  k <- tolower(trimws(k)); k <- gsub("_", " ", k); k <- gsub("\\s+", " ", k)
  hit <- k %in% names(kw_synonyms)
  k[hit] <- kw_synonyms[k[hit]]
  k
}
M$RID <- seq_len(nrow(M))     # unique row id (UID can collide for residual duplicates)
kw <- M %>% select(RID, CORPUS, stratum, DE) %>% filter(!is.na(DE), DE != "", DE != "NA") %>%
  mutate(kw = strsplit(DE, ";")) %>% unnest(kw) %>%
  mutate(kw = norm_kw(kw)) %>% filter(kw != "") %>% distinct(RID, CORPUS, stratum, kw)
n_docs_kw <- kw %>% distinct(RID, CORPUS) %>% count(CORPUS, name = "docs")
top_kw <- kw %>% count(CORPUS, kw, name = "n") %>%
  left_join(n_docs_kw, by = "CORPUS") %>% mutate(share_of_docs = round(n / docs, 4)) %>%
  group_by(CORPUS) %>% slice_max(n, n = 30, with_ties = FALSE) %>% ungroup()
save_tab(top_kw, "T6_top_author_keywords.csv")
top_kw_all <- kw %>% count(kw, name = "n") %>% slice_max(n, n = 30, with_ties = FALSE)
save_tab(top_kw_all, "T6b_top_author_keywords_all.csv")

# Exact counts of ML/DL-related author keywords
ml_kw_pat <- c("machine learning" = "^machine learning$", "deep learning" = "^deep learning$",
               "neural network" = "neural network", "lstm" = "^lstm$", "random forest" = "^random forest$",
               "svm" = "^svm$", "xgboost|boosting" = "xgboost|boosting", "autoencoder" = "autoencoder",
               "reinforcement learning" = "reinforcement learning", "transformer" = "^transformer",
               "artificial intelligence" = "^artificial intelligence$|^ai$",
               "concept drift" = "concept drift", "clustering|k-means" = "clustering|k-means",
               "change point (all variants)" = "^change point$", "structural break (all variants)" = "^structural break$",
               "regime switching (all variants)" = "^regime switching$", "markov switching (all variants)" = "^markov switching$")
ml_kw_counts <- lapply(names(ml_kw_pat), function(nm)
  kw %>% filter(grepl(ml_kw_pat[[nm]], kw)) %>% count(CORPUS, name = "n") %>%
    tidyr::complete(CORPUS = c("A", "B"), fill = list(n = 0)) %>%
    pivot_wider(names_from = CORPUS, values_from = n) %>% mutate(keyword = nm, total = A + B)) %>%
  bind_rows() %>% select(keyword, A, B, total)
save_tab(ml_kw_counts, "T6c_ml_keyword_counts.csv")
cat("\nAuthor-keyword occurrences (documents), screened corpus:\n"); print(ml_kw_counts)

# ---- 6. Method-family prevalence ----------------------------------------------------
txt <- toupper(paste(M$TI, M$AB, M$DE))
txt[is.na(txt)] <- ""
families <- c(
  "Classical break tests" = "CHOW TEST|BAI[- ]PERRON|BAI AND PERRON|CUSUM|MOSUM|\\bSUP[- ]?F\\b|QUANDT|ZIVOT|STRAZICICH|\\bICSS\\b|INCLAN|FLUCTUATION TEST|STRUCTURAL BREAKS? TESTS?|TESTS? FOR (A |MULTIPLE )?STRUCTURAL (BREAK|CHANGE)",
  "Segmentation algorithms" = "\\bPELT\\b|BINARY SEGMENTATION|WILD BINARY|OPTIMAL PARTITION|PENALI[SZ]ED (CONTRAST|LIKELIHOOD|COST)",
  "Markov / regime switching" = "MARKOV[- ]SWITCH|REGIME[- ]SWITCH|MARKOV REGIME|HIDDEN MARKOV|\\bHMMS?\\b",
  "Threshold / smooth transition" = "THRESHOLD AUTOREGRESS|\\bTAR\\b|SMOOTH TRANSITION|\\bSTAR\\b|\\bLSTAR\\b|\\bESTAR\\b",
  "Volatility models (GARCH/SV)" = "GARCH|STOCHASTIC VOLATILITY|\\bARCH\\b",
  "Bayesian" = "BAYESIAN|MCMC|GIBBS|\\bBOCPD\\b|PRODUCT PARTITION",
  "State-space / filtering" = "STATE[- ]SPACE|KALMAN|PARTICLE FILTER",
  "Wavelet / frequency" = "WAVELET",
  "Nonparametric / kernel" = "NONPARAMETRIC|NON-PARAMETRIC|KERNEL|E-DIVISIVE|ENERGY STATISTIC|MAXIMUM MEAN DISCREPANCY|\\bMMD\\b|RANK[- ]BASED",
  # Main ML/DL definition = the one used in 02b_screening.R (ML_vocab): learning
  # methods only. The broad variant below adds clustering and concept drift.
  "Machine / deep learning" = "\\b(MACHINE LEARNING|DEEP LEARNING|NEURAL NETWORKS?|LSTM|RECURRENT NEURAL|CONVOLUTIONAL|TRANSFORMERS?\\b|RANDOM FORESTS?|SUPPORT VECTOR|GRADIENT BOOST|XGBOOST|AUTOENCODERS?|REINFORCEMENT LEARNING|GENERATIVE ADVERSARIAL|ATTENTION MECHANISM|KERNEL (TWO[- ]SAMPLE|CHANGE|METHOD)|GAUSSIAN PROCESS|SELF[- ]SUPERVISED|UNSUPERVISED LEARNING|SUPERVISED LEARNING)",
  "ML/DL broad (incl. clustering, concept drift)" = "MACHINE LEARNING|DEEP LEARNING|NEURAL NETWORK|\\bLSTM\\b|RECURRENT NEURAL|CONVOLUTIONAL|TRANSFORMER (MODEL|NETWORK|ARCHITECTURE)|ATTENTION MECHANISM|SELF[- ]ATTENTION|RANDOM FOREST|SUPPORT VECTOR|\\bSVM\\b|GRADIENT BOOSTING|XGBOOST|AUTOENCODER|REINFORCEMENT LEARNING|K[- ]MEANS|CLUSTER ANALYSIS|CLUSTERING ALGORITHM|SPECTRAL CLUSTERING|UNSUPERVISED LEARNING|SUPERVISED LEARNING|CONCEPT DRIFT"
)
for (f in names(families)) M[[f]] <- grepl(families[[f]], txt, perl = TRUE)
M$period <- cut(M$PY, c(2009, 2014, 2019, 2022, 2025),
                labels = c("2010-2014", "2015-2019", "2020-2022", "2023-2025"))

fam_share <- function(D, by) {
  lapply(names(families), function(f) {
    D %>% group_by(across(all_of(by))) %>%
      summarise(x = sum(.data[[f]]), n = n(), .groups = "drop") %>%
      bind_cols(wilson(.$x, .$n)) %>% mutate(family = f)
  }) %>% bind_rows()
}
fam_overall <- fam_share(M, "CORPUS")
fam_stratum <- fam_share(M, c("CORPUS", "stratum"))
fam_period  <- fam_share(M, c("CORPUS", "stratum", "period"))
save_tab(fam_overall, "T7_method_families_by_corpus.csv")
save_tab(fam_stratum, "T7b_method_families_by_corpus_stratum.csv")
save_tab(fam_period,  "T7c_method_families_by_corpus_stratum_period.csv")

p_fam <- ggplot(fam_stratum %>% filter(family != "ML/DL broad (incl. clustering, concept drift)"),
                aes(x = reorder(family, share), y = 100 * share, fill = CORPUS)) +
  geom_col(position = position_dodge(0.8), width = 0.75) +
  geom_errorbar(aes(ymin = 100 * lo, ymax = 100 * hi), position = position_dodge(0.8), width = 0.25) +
  coord_flip() + facet_wrap(~ stratum) +
  scale_fill_manual(values = cols_ab, labels = corp_lab, name = NULL) +
  labs(x = NULL, y = "Share of documents mentioning the family (%)") +
  theme_minimal(base_size = 11) + theme(legend.position = "bottom")
save_fig(p_fam, "F7_method_families", w = 9, h = 5.5)

# ML/DL share per year among DETECTION papers (T1) and among all retained papers
ml_year <- M %>% group_by(stratum, CORPUS, PY) %>%
  summarise(x = sum(`Machine / deep learning`), n = n(), .groups = "drop") %>%
  bind_cols(wilson(.$x, .$n))
save_tab(ml_year, "T8_ml_share_by_year_stratum.csv")
p_ml <- ggplot(ml_year %>% filter(stratum == "T1 detection"),
               aes(PY, 100 * share, colour = CORPUS, fill = CORPUS)) +
  geom_ribbon(aes(ymin = 100 * lo, ymax = 100 * hi), alpha = 0.15, colour = NA) +
  geom_line(linewidth = 0.8) + geom_point(size = 1.5) +
  scale_colour_manual(values = cols_ab, labels = corp_lab, name = NULL) +
  scale_fill_manual(values = cols_ab, labels = corp_lab, name = NULL) +
  scale_x_continuous(breaks = seq(2010, 2025, 3)) +
  labs(x = "Publication year", y = "Detection papers mentioning ML/DL (%)") +
  theme_minimal(base_size = 11) + theme(legend.position = "bottom")
save_fig(p_ml, "F8_ml_share_by_year_detection")

ml_period <- M %>% filter(stratum == "T1 detection") %>% group_by(period, CORPUS) %>%
  summarise(x = sum(`Machine / deep learning`), n = n(), .groups = "drop") %>%
  bind_cols(wilson(.$x, .$n)) %>% mutate(across(c(share, lo, hi), ~ round(.x, 3)))
save_tab(ml_period, "T8b_ml_share_by_period_detection.csv"); print(ml_period)

# ---- 7. Sensitivity: retrieved without the regime-switching terms -------------------
pheno_no_rs <- paste0(
  "CHANGE[- ]?POINT|STRUCTURAL BREAK|STRUCTURAL INSTABILIT|PARAMETER INSTABILIT|",
  "REGIME CHANGE|REGIME SHIFT|BREAK[- ]?POINT|BREAK DATE|TREND BREAK|CHANGE DETECTION|",
  "CONCEPT DRIFT|TIME SERIES SEGMENTATION|BAI[- ]PERRON|BAI AND PERRON|CHOW TEST|CUSUM|",
  "ZIVOT[- ]ANDREWS|ZIVOT AND ANDREWS|\\bICSS\\b|INCLAN|\\bSUP[- ]?F\\b|SUPF|QUANDT|\\bPELT\\b|",
  "BINARY SEGMENTATION")
ti_kw <- toupper(paste(M$TI, M$DE))
M$retrieved_without_RS <- grepl(pheno_no_rs, txt, perl = TRUE) | grepl("STRUCTURAL CHANGE", ti_kw)
sens <- M %>% group_by(CORPUS) %>%
  summarise(n_all = n(), n_without_RS_terms = sum(retrieved_without_RS),
            share_retained = round(n_without_RS_terms / n_all, 3), .groups = "drop")
save_tab(sens, "T9a_sensitivity_sizes.csv"); print(sens)
fam_sens <- fam_share(M[M$retrieved_without_RS, ], "CORPUS") %>% mutate(subset = "without RS terms") %>%
  bind_rows(fam_overall %>% mutate(subset = "full corpus"))
save_tab(fam_sens, "T9b_sensitivity_method_families.csv")

# ---- 8. Keyword co-occurrence network, VOSviewer map/network files ----------------
# VOSviewer: File > Open > "VOSviewer map file" + "VOSviewer network file".
# Keywords are the normalised author keywords (synonym table above), so the
# thesaurus is applied here rather than in VOSviewer.
write_vos <- function(K, prefix, min_occ = 10) {
  # K: data frame RID, kw (one row per document-keyword)
  freq <- K %>% count(kw, name = "occ") %>% filter(occ >= min_occ) %>% arrange(desc(occ)) %>%
    mutate(id = row_number())
  Kf <- K %>% inner_join(freq %>% select(kw, id), by = "kw")
  pairs <- Kf %>% inner_join(Kf, by = "RID", suffix = c("1", "2"), relationship = "many-to-many") %>%
    filter(id1 < id2) %>% count(id1, id2, name = "weight")
  # Publication year of each keyword (mean over its documents) for the overlay
  yr <- K %>% inner_join(M %>% select(RID, PY), by = "RID") %>% group_by(kw) %>%
    summarise(score = round(mean(PY, na.rm = TRUE), 2), .groups = "drop")
  map <- freq %>% left_join(yr, by = "kw") %>%
    transmute(id, label = kw, weight = occ, `score<Avg. pub. year>` = score)
  write.table(map, paste0("output/vosviewer/", prefix, "_map.txt"), sep = "\t",
              row.names = FALSE, quote = FALSE)
  write.table(pairs, paste0("output/vosviewer/", prefix, "_network.txt"), sep = "\t",
              row.names = FALSE, col.names = FALSE, quote = FALSE)
  cat(sprintf("VOSviewer files written: %s (%d keywords, %d links)\n", prefix, nrow(map), nrow(pairs)))
}
write_vos(kw %>% select(RID, kw), "kw_all",       min_occ = 10)
write_vos(kw %>% filter(stratum == "T1 detection") %>% select(RID, kw), "kw_detection", min_occ = 5)
write_vos(kw %>% filter(CORPUS == "A") %>% select(RID, kw), "kw_corpusA", min_occ = 10)
write_vos(kw %>% filter(CORPUS == "B") %>% select(RID, kw), "kw_corpusB", min_occ = 5)

# ---- 8b. Keyword co-occurrence network drawn in R (no VOSviewer needed) --------------
# Built from the same normalised author keywords as the VOSviewer files, on the
# top n_nodes keywords only (memory-light: biblioNetwork on 9,000 records is not
# needed). Node size = occurrences, colour = Louvain community, edge width =
# co-occurrence count. One figure for the full corpus, one for the detection stratum.
draw_cooc <- function(K, name, n_nodes = 50, min_w = 3) {
  ok <- tryCatch({
    if (!requireNamespace("igraph", quietly = TRUE)) stop("package igraph not installed")
    freq <- K %>% count(kw, name = "occ") %>% slice_max(occ, n = n_nodes, with_ties = FALSE)
    Kf <- K %>% filter(kw %in% freq$kw)
    pairs <- Kf %>% inner_join(Kf, by = "RID", suffix = c("1", "2"), relationship = "many-to-many") %>%
      filter(kw1 < kw2) %>% count(kw1, kw2, name = "w") %>% filter(w >= min_w)
    g <- igraph::graph_from_data_frame(pairs, directed = FALSE,
                                       vertices = freq %>% rename(name = kw))
    g <- igraph::delete_vertices(g, igraph::degree(g) == 0)
    set.seed(2026)
    cl <- igraph::cluster_louvain(g, weights = igraph::E(g)$w)
    pal <- c("#1f4e79", "#c55a11", "#548235", "#7030a0", "#bf9000", "#2e75b6", "#c00000", "#7f7f7f")
    png(file.path("output/figures", paste0(name, ".png")), width = 2600, height = 2200, res = 300)
    par(mar = c(0.5, 0.5, 0.5, 0.5))
    lay <- igraph::layout_with_fr(g, weights = igraph::E(g)$w)
    plot(g, layout = lay,
         vertex.size = 3 + 22 * sqrt(igraph::V(g)$occ / max(igraph::V(g)$occ)),
         vertex.color = adjustcolor(pal[((igraph::membership(cl) - 1) %% length(pal)) + 1], 0.85),
         vertex.frame.color = "white", vertex.label.cex = 0.55, vertex.label.color = "black",
         vertex.label.family = "sans",
         edge.width = 0.3 + 3 * igraph::E(g)$w / max(igraph::E(g)$w), edge.color = adjustcolor("grey55", 0.5))
    dev.off()
    memb <- data.frame(keyword = igraph::V(g)$name, occurrences = igraph::V(g)$occ,
                       community = as.integer(igraph::membership(cl)))
    write.csv(memb, file.path("output/tables", paste0(name, "_communities.csv")), row.names = FALSE)
    TRUE
  }, error = function(e) { try(dev.off(), silent = TRUE)
    message("Co-occurrence figure ", name, " skipped: ", conditionMessage(e)); FALSE })
  ok
}
draw_cooc(kw %>% select(RID, kw), "F7b_keyword_cooccurrence_all", 50)
draw_cooc(kw %>% filter(stratum == "T1 detection") %>% select(RID, kw), "F7c_keyword_cooccurrence_detection", 50)

# ---- 9. Three-field plot (countries - author keywords - sources) ---------------------
tfp_ok <- tryCatch({
  Mc <- metaTagExtraction(M, Field = "AU_CO", sep = ";")
  Mc$DE <- sapply(strsplit(Mc$DE, ";"), function(v) paste(toupper(norm_kw(v)), collapse = ";"))
  tfp <- threeFieldsPlot(Mc, fields = c("AU_CO", "DE", "SO"), n = c(10, 10, 10))
  htmlwidgets::saveWidget(tfp, "output/figures/F8_three_field_plot.html", selfcontained = TRUE)
  TRUE
}, error = function(e) { message("Three-field plot skipped: ", conditionMessage(e)); FALSE })

# ---- Console summary ----------------------------------------------------------------
cat("\nShare of documents mentioning each family (%), by corpus and stratum:\n")
print(fam_stratum %>% transmute(CORPUS, stratum, family, pct = round(100 * share, 1)) %>%
        pivot_wider(names_from = c(CORPUS, stratum), values_from = pct) %>% as.data.frame())
saveRDS(M, "output/M_tagged.rds")
cat("\nSaved tables in output/tables, figures in output/figures, VOSviewer files in output/vosviewer,",
    "and output/M_tagged.rds\n")
