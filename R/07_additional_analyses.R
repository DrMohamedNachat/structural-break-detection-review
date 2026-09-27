# =============================================================================
# 07_additional_analyses.R
# Additional analyses: sub-corpora, cross-citation detail, sensitivities
#
# Input : output/M_tagged.rds (03), output/W_wos.rds (01, optional),
#         output/tables/V3_ml_census.csv and output/validation_ml_to_code.csv (08)
# Output: output/tables/X1_B_subcorpora.csv         composition of B1 / B2 / B0
#         output/tables/X2_families_by_subcorpus.csv family shares, detection stratum, A / B1 / B2
#         output/tables/X3_ml_by_subcorpus_period.csv ML mention and validated use, A / B1 / B2 by period
#         output/tables/X4_crosscite_subcorpus.csv    links A -> A / B1 / B2, ratios
#         output/tables/X5_crosscite_period_timeaware.csv  A->B share by period, time-aware ratio, citing-paper bootstrap CI
#         output/tables/X6_gap_heatmap_counts.csv     family x application-domain cross-tabulation (detection stratum)
#         output/tables/X7_document_types.csv
#         output/tables/X8_sources_in_both_corpora.csv
#         output/tables/X9_sensitivity_R2_on_A.csv    ML shares when rule R2 is applied to corpus A as well
#         output/tables/X10_sensitivity_concept_drift.csv  ML shares excluding records qualified only by "concept drift"
#         output/figures/F11_gap_heatmap_data.csv     copy of X6 for the Python figure script
# =============================================================================
suppressMessages({ library(dplyr); library(tidyr) })
dir.create("output/tables", showWarnings = FALSE, recursive = TRUE)
dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)
M <- readRDS("output/M_tagged.rds")
M$PY <- as.numeric(M$PY)
M$stratum <- ifelse(M$tier == "T2_regime_switching_modelling", "T2 modelling", "T1 detection")
M$period <- cut(M$PY, c(2009, 2014, 2019, 2022, 2025), labels = c("2010-2014", "2015-2019", "2020-2022", "2023-2025"))
ML <- "Machine / deep learning"
wilson <- function(x, n, z = 1.96) { p <- x / n; den <- 1 + z^2 / n
  data.frame(share = p, lo = pmax(0, (p + z^2/(2*n))/den - z*sqrt(p*(1-p)/n + z^2/(4*n^2))/den),
             hi = pmin(1, (p + z^2/(2*n))/den + z*sqrt(p*(1-p)/n + z^2/(4*n^2))/den)) }
up <- function(x) { x <- toupper(as.character(x)); x[is.na(x) | x == "NA"] <- ""; x }
sc <- up(M$SC)

# ---- 1. Split corpus B by WoS research area ------------------------------------------
B1_areas <- c("MATHEMATICS", "COMPUTER SCIENCE", "PHYSICS", "OPERATIONS RESEARCH & MANAGEMENT SCIENCE",
              "MATHEMATICAL METHODS IN SOCIAL SCIENCES", "AUTOMATION & CONTROL SYSTEMS", "ENGINEERING",
              "TELECOMMUNICATIONS", "INSTRUMENTS & INSTRUMENTATION")
B2_areas <- c("ENVIRONMENTAL SCIENCES & ECOLOGY", "ENERGY & FUELS", "AGRICULTURE", "GEOLOGY", "WATER RESOURCES",
              "METEOROLOGY & ATMOSPHERIC SCIENCES", "PUBLIC, ENVIRONMENTAL & OCCUPATIONAL HEALTH", "THERMODYNAMICS")
areas <- strsplit(sc, ";\\s*")
has_area <- function(set) sapply(areas, function(v) any(trimws(v) %in% set))
inB1 <- has_area(B1_areas); inB2 <- has_area(B2_areas); hasSC <- nchar(sc) > 0
sub <- ifelse(M$CORPUS == "A", "A",
       ifelse(!hasSC, "B0",                        # no WoS category (Scopus-only record)
       ifelse(inB2, "B2", ifelse(inB1, "B1", "B2"))))   # energy/environment wins; other areas -> B2
# Scopus-only records: inherit the label of their source when the source is labelled elsewhere in B
src_lab <- M %>% mutate(sub = sub) %>% filter(CORPUS == "B", sub %in% c("B1", "B2")) %>%
  count(SO, sub) %>% group_by(SO) %>% slice_max(n, n = 1, with_ties = FALSE) %>% ungroup()
i0 <- which(sub == "B0"); m <- match(M$SO[i0], src_lab$SO)
sub[i0[!is.na(m)]] <- src_lab$sub[m[!is.na(m)]]
M$sub <- sub
X1 <- M %>% count(CORPUS, sub, stratum) %>% pivot_wider(names_from = stratum, values_from = n, values_fill = 0) %>%
  mutate(total = `T1 detection` + `T2 modelling`)
write.csv(X1, "output/tables/X1_B_subcorpora.csv", row.names = FALSE); print(X1)
cat("B1 = mathematics, computer science, physics, OR, engineering venues; B2 = energy, environment and other venues;",
    "B0 = Scopus-only records whose source could not be labelled\n")
top_src <- M %>% filter(sub %in% c("B1", "B2")) %>% count(sub, SO) %>% group_by(sub) %>% slice_max(n, n = 10) %>% ungroup()
write.csv(top_src, "output/tables/X1b_top_sources_B1_B2.csv", row.names = FALSE)

# ---- 2. Method families in the detection stratum, A / B1 / B2 ----------------------------
fams <- c("Classical break tests", "Segmentation algorithms", "Markov / regime switching", "Threshold / smooth transition",
          "Volatility models (GARCH/SV)", "Bayesian", "State-space / filtering", "Wavelet / frequency",
          "Nonparametric / kernel", ML)
det <- M %>% filter(stratum == "T1 detection", sub %in% c("A", "B1", "B2"))
X2 <- lapply(fams, function(f) det %>% group_by(sub) %>% summarise(x = sum(.data[[f]]), n = n(), .groups = "drop") %>%
               bind_cols(wilson(.$x, .$n)) %>% mutate(family = f)) %>% bind_rows() %>%
  mutate(across(c(share, lo, hi), ~ round(100 * .x, 1)))
write.csv(X2, "output/tables/X2_families_by_subcorpus.csv", row.names = FALSE)
print(X2 %>% filter(family %in% c("Classical break tests", ML, "Segmentation algorithms", "Nonparametric / kernel")) %>% as.data.frame())

# ---- 3. ML mention and validated use by sub-corpus and period -------------------------------
V <- read.csv("output/validation_ml_to_code.csv", stringsAsFactors = FALSE)
M$ml_validated <- FALSE
M$ml_validated[match(V$UID[V$ML_used_for_detection == 1], M$UID)] <- TRUE
X3 <- bind_rows(
  det %>% mutate(ml_validated = M$ml_validated[match(UID, M$UID)]) %>% group_by(sub, period) %>%
    summarise(n = n(), mention = sum(.data[[ML]]), validated = sum(ml_validated), .groups = "drop") %>% mutate(period = as.character(period)),
  det %>% mutate(ml_validated = M$ml_validated[match(UID, M$UID)]) %>% group_by(sub) %>%
    summarise(n = n(), mention = sum(.data[[ML]]), validated = sum(ml_validated), .groups = "drop") %>% mutate(period = "all")) %>%
  mutate(mention_pct = round(100 * mention / n, 2), validated_pct = round(100 * validated / n, 2))
write.csv(X3, "output/tables/X3_ml_by_subcorpus_period.csv", row.names = FALSE); print(as.data.frame(X3))

# ---- 4. Cross-citation by sub-corpus and time-aware ratio by period ----------------------------
norm_doi <- function(x) { x <- tolower(trimws(as.character(x))); x <- sub("^https?://(dx\\.)?doi\\.org/", "", x)
  x <- sub("[\\.,;\\]\\)]+$", "", x); x[x %in% c("", "na")] <- NA; x }
if ("CR_raw" %in% names(M)) M$CR <- M$CR_raw
M$doi_n <- norm_doi(M$DI)
cited <- M %>% filter(!is.na(doi_n)) %>% distinct(doi_n, .keep_all = TRUE) %>%
  transmute(doi_n, cited_corpus = CORPUS, cited_sub = sub, cited_PY = PY)
citing <- M %>% filter(SOURCE_DB %in% c("WoS", "Both"), !is.na(CR), nchar(CR) > 0) %>%
  select(UID, CORPUS, sub, PY, doi_self = doi_n, CR)
refs <- citing %>% mutate(ref = strsplit(CR, ";")) %>% select(-CR) %>% unnest(ref) %>% mutate(ref = trimws(ref))
refs$doi_r <- ifelse(grepl("\\bDOI\\b", refs$ref), sub(".*\\bDOI\\s+\\[?", "", refs$ref), NA)
refs$doi_r <- norm_doi(sub("[, ].*$", "", refs$doi_r))
links <- refs %>% filter(!is.na(doi_r), is.na(doi_self) | doi_r != doi_self) %>%
  inner_join(cited, by = c("doi_r" = "doi_n")) %>% distinct(UID, doi_r, .keep_all = TRUE)
citable <- cited %>% count(cited_sub, name = "citable") %>% mutate(citable_share = citable / sum(citable))
X4 <- links %>% filter(CORPUS == "A") %>% count(cited_sub, name = "links") %>%
  mutate(share = links / sum(links)) %>% left_join(citable, by = "cited_sub") %>%
  mutate(ratio = round(share / citable_share, 3), share = round(share, 3), citable_share = round(citable_share, 3))
write.csv(X4, "output/tables/X4_crosscite_subcorpus.csv", row.names = FALSE)
cat("\nLinks from corpus A by cited sub-corpus:\n"); print(as.data.frame(X4))

# Time-aware expected share of B among citable documents published up to year y
cumB <- cited %>% count(cited_PY, cited_corpus) %>% pivot_wider(names_from = cited_corpus, values_from = n, values_fill = 0) %>%
  arrange(cited_PY) %>% mutate(shareB = cumsum(B) / (cumsum(A) + cumsum(B)))
LA <- links %>% filter(CORPUS == "A") %>% mutate(period = cut(PY, c(2009, 2014, 2019, 2022, 2025),
                                                     labels = c("2010-2014", "2015-2019", "2020-2022", "2023-2025")),
                                         toB = cited_corpus == "B",
                                         expB = cumB$shareB[match(PY, cumB$cited_PY)])
per <- LA %>% group_by(period) %>% summarise(links = n(), citing_papers = n_distinct(UID), share_to_B = mean(toB),
                                             expected_share_B = mean(expB), .groups = "drop") %>%
  mutate(ratio_time_aware = share_to_B / expected_share_B)
# Cluster bootstrap by citing paper (links of one paper are not independent)
set.seed(2026); Bn <- 2000
boot <- lapply(levels(LA$period), function(p) {
  Lp <- LA %>% filter(period == p); ids <- unique(Lp$UID); byid <- split(Lp$toB, Lp$UID); byex <- split(Lp$expB, Lp$UID)
  st <- replicate(Bn, { s <- sample(ids, replace = TRUE); v <- unlist(byid[s]); e <- unlist(byex[s]); c(mean(v), mean(v) / mean(e)) })
  data.frame(period = p, share_lo = quantile(st[1, ], 0.025), share_hi = quantile(st[1, ], 0.975),
             ratio_lo = quantile(st[2, ], 0.025), ratio_hi = quantile(st[2, ], 0.975), row.names = NULL) }) %>% bind_rows()
X5 <- per %>% left_join(boot, by = "period") %>% mutate(across(where(is.numeric) & !c(links, citing_papers), ~ round(.x, 3)))
write.csv(X5, "output/tables/X5_crosscite_period_timeaware.csv", row.names = FALSE)
cat("\nCorpus A -> B by period (citing-paper bootstrap):\n"); print(as.data.frame(X5))

# ---- 5. Computed gap heatmap: method family x application domain (detection stratum) ------------
txt <- up(paste(M$TI, M$AB, M$DE))
domains <- c(
  "Stock markets" = "STOCK (MARKET|PRICE|RETURN|INDEX|INDICES)|EQUITY (MARKET|RETURN|PRICE)|SHARE PRICE",
  "Exchange rates" = "EXCHANGE RATE|FOREIGN EXCHANGE|FOREX|CURRENCY MARKET",
  "Oil & commodities" = "OIL PRICE|CRUDE OIL|COMMODIT|GOLD PRICE|GAS PRICE|METAL",
  "Interest rates & bonds" = "INTEREST RATE|BOND (MARKET|YIELD|PRICE)|YIELD CURVE|TERM STRUCTURE|SOVEREIGN",
  "Macro indicators" = "\\bGDP\\b|INFLATION|OUTPUT GAP|UNEMPLOYMENT|BUSINESS CYCLE|MONETARY POLICY|INDUSTRIAL PRODUCTION",
  "Cryptocurrencies" = "CRYPTOCURRENC|BITCOIN|ETHEREUM",
  "Derivatives & options" = "OPTION PRIC|DERIVATIVE|FUTURES|IMPLIED VOLATILITY",
  "Risk management" = "VALUE[- ]AT[- ]RISK|PORTFOLIO|HEDG|RISK MANAGEMENT|EXPECTED SHORTFALL",
  "Energy & environment" = "ENERGY CONSUMPTION|CO2|CARBON EMISSION|EMISSIONS|ENVIRONMENTAL (KUZNETS|QUALITY|DEGRADATION)|RENEWABLE")
D <- sapply(domains, function(p) grepl(p, txt, perl = TRUE))
detidx <- M$stratum == "T1 detection"
X6 <- expand.grid(family = fams, domain = names(domains), stringsAsFactors = FALSE)
X6$n <- mapply(function(f, d) sum(M[[f]] & D[, d] & detidx), X6$family, X6$domain)
X6$domain_total <- sapply(X6$domain, function(d) sum(D[, d] & detidx))
X6$share_of_domain_pct <- round(100 * X6$n / X6$domain_total, 1)
write.csv(X6, "output/tables/X6_gap_heatmap_counts.csv", row.names = FALSE)
write.csv(X6, "output/figures/F11_gap_heatmap_data.csv", row.names = FALSE)
cat("\nGap heatmap counts written (detection stratum). ML row:\n")
print(X6 %>% filter(family == ML) %>% select(domain, n, domain_total, share_of_domain_pct))

# ---- 6. Document types, sources in both corpora ---------------------------------------------
X7 <- M %>% count(DT, name = "n") %>% mutate(pct = round(100 * n / sum(n), 2)) %>% arrange(desc(n))
write.csv(X7, "output/tables/X7_document_types.csv", row.names = FALSE); print(X7)
X8 <- M %>% distinct(SO, CORPUS, SOURCE_DB) %>% count(SO, CORPUS) %>% pivot_wider(names_from = CORPUS, values_from = n, values_fill = 0) %>%
  filter(A > 0, B > 0)
X8 <- M %>% filter(SO %in% X8$SO) %>% count(SO, CORPUS, SOURCE_DB) %>% arrange(SO)
write.csv(X8, "output/tables/X8_sources_in_both_corpora.csv", row.names = FALSE)
cat("\nSources appearing in both corpora:", n_distinct(X8$SO), "\n"); print(as.data.frame(X8))

# ---- 7. Sensitivities: R2 applied to corpus A; records qualified only by "concept drift" ---------
mlshare <- function(D, label) D %>% filter(stratum == "T1 detection") %>% group_by(CORPUS) %>%
  summarise(n = n(), ml = sum(.data[[ML]]), .groups = "drop") %>% mutate(pct = round(100 * ml / n, 2), subset = label)
X9 <- bind_rows(mlshare(M, "all retained"), mlshare(M %>% filter(CORPUS == "B" | FIN), "R2 applied to A as well"))
write.csv(X9, "output/tables/X9_sensitivity_R2_on_A.csv", row.names = FALSE); print(X9)
only_drift <- grepl("\\bCONCEPT DRIFT\\b", txt, perl = TRUE) &
  !grepl("\\bCHANGE[- ]?POINT|\\bSTRUCTURAL BREAK|\\bBREAK DATE|\\bTREND BREAK|\\bSTRUCTURAL INSTABILIT|\\bPARAMETER INSTABILIT|\\bBAI[- ](AND[- ])?PERRON|\\bCHOW TEST|\\bZIVOT|\\bQUANDT|\\bINCLAN|\\bSUP[- ]?F\\b|\\bBINARY SEGMENTATION|\\bTIME[- ]SERIES SEGMENTATION|\\bCUSUM|\\bICSS\\b|\\bPELT\\b|\\bBREAK[- ]?POINT|\\bSTRUCTURAL CHANGE|\\bCHANGE DETECTION|\\bREGIME|\\bMARKOV[- ]SWITCH|\\bHIDDEN MARKOV", txt, perl = TRUE)
X10 <- bind_rows(mlshare(M, "all retained"), mlshare(M[!only_drift, ], "excluding concept-drift-only records")) %>%
  mutate(n_concept_drift_only = sum(only_drift))
write.csv(X10, "output/tables/X10_sensitivity_concept_drift.csv", row.names = FALSE); print(X10)
saveRDS(M, "output/M_tagged.rds")   # now carries 'sub' and 'ml_validated'
cat("\nSaved X1-X10\n")
