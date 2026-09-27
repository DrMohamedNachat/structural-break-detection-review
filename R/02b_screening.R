# =============================================================================
# 02b_screening.R
# Phase 2: rule-based eligibility screening
#
# Applied to BOTH corpora.
# Every rule is lexical and reproducible: a record is screened on title (TI),
# author keywords (DE) and abstract (AB). Nothing is coded by hand here; the
# rules are validated afterwards on a random sample (see section 6).
#
# Eligibility (a record is RETAINED if all four conditions hold):
#   R1  it contains change-point / structural-break DETECTION vocabulary (S1)
#       or regime-switching MODELLING vocabulary (S2). Ambiguous terms
#       (CUSUM, ICSS, PELT, breakpoint, structural change, change detection,
#       concept drift, regime shift/change) count only with a detection or
#       testing context in the same record;
#   R2  it addresses financial / macroeconomic time series: automatically true
#       for corpus A (economics & business venues by database classification);
#       for corpus B a compound financial term is required (e.g. "stock market",
#       "exchange rate", not "stock" or "credit" alone);
#   R3  no off-domain marker in title or author keywords (remote sensing,
#       ecology, clinical, genomics, ...), unless the title itself carries a
#       strong financial-market term;
#   R4  it is not part of the structural-transformation (growth) literature
#       that uses "structural change" in the sectoral sense.
#
# Retained records are stratified into
#   T1a  explicit detection vocabulary (change point, structural break, Bai-Perron ...)
#   T1b  contextual detection vocabulary (CUSUM, breakpoint, ... with a test context)
#   T1c  CUSUM used only as an ARDL stability diagnostic
#   T2   regime-switching modelling without detection vocabulary
# The strata make the distinction "detection of breaks" vs "modelling of
# regimes" explicit.
#
# Input : output/M_merged.rds   (from 01_import_merge.R)
# Output: output/M_screened.rds, output/screening_flags.csv,
#         output/tables/S1_screening_counts.csv, output/tables/S2_strata.csv,
#         output/tables/S3_ml_share_by_period.csv,
#         output/validation_screening_to_code.csv (+ _key.csv),
#         output/validation_ml_to_code.csv
# Tested with R 4.3.3 / dplyr on output/M_merged.rds (12,005 records, 10 residual duplicates dropped): 9,112 retained.
# =============================================================================

suppressMessages({ library(dplyr) })
dir.create("output/tables", showWarnings = FALSE, recursive = TRUE)

M <- readRDS("output/M_merged.rds")
M$PY <- as.numeric(M$PY)
# Residual duplicates: same DOI written with different punctuation survive the
# DOI match of 01 (UID is built on the punctuation-free DOI). Keep the first.
n_dup <- sum(duplicated(M$UID))
if (n_dup > 0) { cat("Residual duplicate UIDs removed:", n_dup, "\n"); M <- M[!duplicated(M$UID), ] }

up <- function(x) { x <- toupper(as.character(x)); x[is.na(x) | x == "NA"] <- ""; x }
TI <- up(M$TI); DE <- up(M$DE); AB <- up(M$AB)
TXT <- paste(TI, DE, AB)     # title + author keywords + abstract
TK  <- paste(TI, DE)         # title + author keywords
has <- function(pattern, x = TXT) grepl(pattern, x, perl = TRUE)

# ---- 1. R1: detection (S1) and regime-switching (S2) vocabulary ----------------
s1_core <- has(paste0(
  "\\bCHANGE[- ]?POINTS?\\b|\\bSTRUCTURAL BREAKS?\\b|\\bBREAK DATES?\\b|\\bTREND BREAKS?\\b|",
  "\\bSTRUCTURAL INSTABILIT|\\bPARAMETER INSTABILIT|\\bBAI[- ](AND[- ])?PERRON\\b|",
  "\\bCHOW TESTS?\\b|\\bZIVOT[- ](AND[- ])?ANDREWS\\b|\\bQUANDT\\b|\\bINCLAN[- ](AND[- ])?TIAO\\b|",
  "\\bSUP[- ]?F\\b|\\bBINARY SEGMENTATION\\b|\\bTIME[- ]SERIES SEGMENTATION\\b"))

s1_ctx <-
  (has("\\bCUSUM") & has("\\b(BREAK|CHANGE[- ]?POINT|STRUCTURAL|STABILITY|MONITOR|DETECT|SEQUENTIAL)")) |
  (has("\\bICSS\\b") & has("\\b(VARIANCE|VOLATILIT|INCLAN|SUM OF SQUARES)")) |
  (has("\\bPELT\\b") & has("\\b(CHANGE[- ]?POINT|SEGMENT|PENALT|PRUNED)")) |
  (has("\\bBREAK[- ]?POINTS?\\b") &
     has("\\b(TEST|STRUCTURAL|REGRESSION|TIME SERIES|ECONOMETRIC|UNIT ROOT|COINTEGRAT|ESTIMAT|DETECT)")) |
  (has("\\bSTRUCTURAL CHANGES?\\b", TK) &
     has("\\b(TESTS?|TESTING|DETECT|BREAKS?|INSTABILIT|CHANGE[- ]?POINT|PARAMETER|COEFFICIENT|REGRESSION|TIME SERIES)")) |
  (has("\\bCHANGE DETECTION\\b") & has("\\b(TIME SERIES|SEQUENTIAL|ONLINE|STREAM|DISTRIBUTION|STATISTIC)") &
     !has("\\b(REMOTE SENSING|SATELLITE|IMAGE|LAND COVER|LAND USE|LIDAR|RADAR|PIXEL)")) |
  (has("\\bCONCEPT DRIFT\\b") & has("\\b(TIME SERIES|STREAM|FINANCIAL|STOCK|MARKET|PRICE|TRADING)"))

# CUSUM as a mere ARDL / bounds-test stability diagnostic (no other detection term)
cusum_diag <- has("\\bCUSUM") & has("\\bARDL\\b|\\bBOUNDS TEST") & !s1_core

s2 <- has("\\bREGIME[- ]SWITCH|\\bMARKOV[- ]SWITCH|\\bHIDDEN MARKOV") |
  (has("\\bREGIME (SHIFTS?|CHANGES?)\\b") &
     has("\\b(MARKOV|SWITCH|TEST|DETECT|BREAK|CHANGE[- ]?POINT|ESTIMAT|IDENTIF)") &
     !has("\\b(POLITICAL|DEMOCRA|AUTHORITARIAN|REVOLUTION|COUP|ECOSYSTEM|ECOLOG|LAKE|MARINE|CORAL|FISH|SPECIES)"))

S1 <- s1_core | s1_ctx
R1 <- S1 | s2

# ---- 2. R2: financial / macroeconomic time-series domain (compound terms) -------
fin <- has(paste0(
  "\\b(STOCK (MARKETS?|PRICES?|RETURNS?|INDEX|INDICES|EXCHANGE)|EQUITY (MARKETS?|RETURNS?|PRICES?|INDEX)|",
  "SHARE PRICES?|ASSET (PRICES?|PRICING|RETURNS?|ALLOCATION|MARKETS?)|EXCHANGE RATES?|FOREIGN EXCHANGE|FOREX|",
  "CURRENCY MARKETS?|CRYPTOCURRENC|BITCOIN|ETHEREUM|COMMODIT(Y|IES) (PRICES?|MARKETS?|FUTURES?)|OIL PRICES?|",
  "CRUDE OIL|GAS PRICES?|GOLD PRICES?|CARBON (PRICES?|MARKETS?|EMISSION ALLOWANCE)|INTEREST RATES?|",
  "BOND (MARKETS?|YIELDS?|PRICES?|RETURNS?)|YIELD CURVE|SOVEREIGN (DEBT|BOND|RISK|SPREAD)|",
  "CREDIT (SPREADS?|RISK|MARKETS?|DEFAULT|GROWTH)|INFLATION|\\bGDP\\b|OUTPUT GAP|MACROECONOM|BUSINESS CYCLES?|",
  "MONETARY POLICY|CENTRAL BANK|FINANCIAL (MARKETS?|TIME SERIES|RETURNS?|ASSETS?|CRIS(IS|ES)|SERIES|DATA|",
  "VOLATILITY|CONTAGION|STABILITY|ECONOMETRIC)|(STOCK|MARKET|RETURN|PRICE|VOLATILITY) (VOLATILITY|SPILLOVER)|",
  "REALIZED VOLATILITY|GARCH|OPTION PRIC|DERIVATIVES? (MARKET|PRICING)|PORTFOLIO|HEDG(E|ING) (RATIO|STRATEG|EFFECTIVENESS)|",
  "HOUS(E|ING) PRICES?|REAL ESTATE (PRICE|MARKET)|TERM STRUCTURE|RISK PREMI|VALUE[- ]AT[- ]RISK|CONTAGION|",
  "ECONOMIC (TIME SERIES|ACTIVITY|GROWTH|INDICATORS?)|UNEMPLOYMENT RATE|FUTURES MARKETS?|ALGORITHMIC TRADING|",
  "TRADING STRATEG|ASSET RETURNS?|EXCESS RETURNS?|DAILY RETURNS?)"))
isA <- M$CORPUS == "A"
R2  <- fin | isA

# ---- 3. R3: off-domain markers (whole words, title + author keywords) ----------
off_words <- c("REMOTE SENSING","SATELLITE","LAND COVER","LAND USE","LIDAR","SYNTHETIC APERTURE","HYPERSPECTRAL",
  "PIXELS?","IMAGE SEGMENTATION","VIDEO","ECOSYSTEMS?","ECOLOG\\w*","LAKES?","RIVERS?","MARINE","CORAL",
  "FISHER(Y|IES)","FISH","SPECIES","FORESTS?","FORESTRY","VEGETATION","SOIL","RAINFALL","PRECIPITATION",
  "HYDROLOG\\w*","STREAMFLOW","GLACIERS?","ICE SHEET","SEISMIC","EARTHQUAKES?","PATIENTS?","CLINICAL",
  "HOSPITALS?","CANCER","TUMOU?RS?","HIV","CORTICAL","NEURO\\w*","EEG","ECG","GENES?","GENOM\\w*",
  "PROTEINS?","DNA","CELLS?","MOLECULAR","WIND POWER","SOLAR POWER","PHOTOVOLTAIC","BATTER(Y|IES)",
  "BEARING","FAULT DIAGNOSIS","INTRUSION DETECTION","MALWARE","RANSOMWARE","WIRELESS","SENSOR NETWORKS?",
  "INDUSTRIAL CONTROL","ROBOTS?","VEHICLES?","TRAFFIC FLOW","PASSENGERS?","WATER QUALITY","AIR QUALITY")
# Note: carbon, emissions, climate, tourism, crops are NOT markers: carbon
# markets, climate-policy uncertainty and agricultural commodity prices are
# legitimate financial/economic time series.
off <- has(paste0("\\b(", paste(off_words, collapse = "|"), ")\\b"), TK)
strong_fin_title <- has(paste0(
  "\\b(STOCK (MARKET|PRICE|RETURN|INDEX)|EXCHANGE RATE|OIL PRICE|INTEREST RATE|BOND|CRYPTOCURRENC|BITCOIN|",
  "GDP|INFLATION|MONETARY POLICY|BUSINESS CYCLE|ASSET PRIC|VOLATILITY|FINANCIAL (MARKET|TIME SERIES|CRIS))"), TI)
R3 <- !(off & !strong_fin_title)

# ---- 4. R4: structural-transformation (growth) literature -----------------------
transf <- has("\\bSTRUCTURAL (CHANGES?|TRANSFORMATION)\\b", TK) &
  has(paste0("\\b(SECTORAL|EMPLOYMENT SHARE|INDUSTRIALI[SZ]ATION|DEINDUSTRIALI[SZ]|AGRICULTUR|MANUFACTURING|",
             "PRODUCTIVITY GROWTH|REALLOCATION|INPUT[- ]OUTPUT|SERVICE SECTOR|THREE[- ]SECTOR|MULTI[- ]SECTOR)")) &
  !s1_core
R4 <- !transf

# ---- 5. Decision, strata and method-vocabulary tags -----------------------------
keep <- R1 & R2 & R3 & R4
tier <- rep("excluded", nrow(M))
tier[keep & s2]                      <- "T2_regime_switching_modelling"
tier[keep & cusum_diag]              <- "T1c_cusum_stability_diag"
tier[keep & s1_ctx & !cusum_diag]    <- "T1b_contextual_detection"
tier[keep & s1_core]                 <- "T1a_core_detection"
reason <- ifelse(keep, "retained",
          ifelse(!R1, "no detection / regime-switching term",
          ifelse(!R2, "no financial term (corpus B)",
          ifelse(!R3, "off-domain marker", "structural-transformation literature"))))
ml <- has(paste0(
  "\\b(MACHINE LEARNING|DEEP LEARNING|NEURAL NETWORKS?|LSTM|RECURRENT NEURAL|CONVOLUTIONAL|TRANSFORMERS?\\b|",
  "RANDOM FORESTS?|SUPPORT VECTOR|GRADIENT BOOST|XGBOOST|AUTOENCODERS?|REINFORCEMENT LEARNING|",
  "GENERATIVE ADVERSARIAL|ATTENTION MECHANISM|KERNEL (TWO[- ]SAMPLE|CHANGE|METHOD)|GAUSSIAN PROCESS|",
  "SELF[- ]SUPERVISED|UNSUPERVISED LEARNING|SUPERVISED LEARNING)"))

M$S1 <- S1; M$S2 <- s2; M$FIN <- fin; M$OFF <- off; M$TRANSF <- transf
M$keep <- keep; M$tier <- tier; M$exclusion_reason <- reason; M$ML_vocab <- ml

cat("\n===== Screening =====\n")
counts <- data.frame(step = c("Residual duplicates removed", "Records screened (A + B)", "Excluded: no detection / regime-switching term",
  "Excluded: no financial term (corpus B)", "Excluded: off-domain marker",
  "Excluded: structural-transformation literature", "Records retained", "  corpus A", "  corpus B",
  "  T1a explicit detection", "  T1b contextual detection", "  T1c CUSUM stability diagnostic",
  "  T2 regime-switching modelling"),
  n = c(n_dup, nrow(M), sum(!R1), sum(R1 & !R2), sum(R1 & R2 & !R3), sum(R1 & R2 & R3 & !R4), sum(keep),
        sum(keep & isA), sum(keep & !isA), sum(tier == "T1a_core_detection"),
        sum(tier == "T1b_contextual_detection"), sum(tier == "T1c_cusum_stability_diag"),
        sum(tier == "T2_regime_switching_modelling")))
print(counts, row.names = FALSE)
write.csv(counts, "output/tables/S1_screening_counts.csv", row.names = FALSE)

strata <- as.data.frame.matrix(table(M$CORPUS, M$tier))
strata$Total <- rowSums(strata)
write.csv(cbind(CORPUS = rownames(strata), strata), "output/tables/S2_strata.csv", row.names = FALSE)

# ML vocabulary among detection papers (T1a + T1b), by period and corpus
det <- M[M$tier %in% c("T1a_core_detection", "T1b_contextual_detection"), ]
det$period <- cut(det$PY, c(2009, 2014, 2019, 2022, 2025),
                  labels = c("2010-2014", "2015-2019", "2020-2022", "2023-2025"))
mlp <- det %>% group_by(period, CORPUS) %>%
  summarise(n_ml = sum(ML_vocab), n = n(), share = round(n_ml / n, 3), .groups = "drop")
print(mlp, n = 20)
write.csv(mlp, "output/tables/S3_ml_share_by_period.csv", row.names = FALSE)

# ---- 6. Validation samples (coded blind by the authors) ----------------------------
set.seed(2026)
idx <- sample(c(sample(which(keep), 75), sample(which(!keep), 75)))
val <- data.frame(ID = sprintf("S%03d", seq_along(idx)), TI = M$TI[idx], SO = M$SO[idx],
                  PY = M$PY[idx], AB = M$AB[idx],
                  coder1_eligible = "", coder2_eligible = "")   # 1 = eligible, 0 = not
write.csv(val, "output/validation_screening_to_code.csv", row.names = FALSE)
write.csv(data.frame(ID = val$ID, rule_retained = as.integer(keep[idx]), tier = tier[idx]),
          "output/validation_screening_key.csv", row.names = FALSE)
mlrec <- M[keep & ml, ]
write.csv(data.frame(UID = mlrec$UID, CORPUS = mlrec$CORPUS, tier = mlrec$tier, PY = mlrec$PY,
                     TI = mlrec$TI, SO = mlrec$SO, AB = mlrec$AB,
                     ML_used_for_detection = "", ML_method = ""),
          "output/validation_ml_to_code.csv", row.names = FALSE)

# ---- 7. Save ----------------------------------------------------------------------
flags <- M[, c("UID", "SR", "DI", "TI", "PY", "SO", "CORPUS", "SOURCE_DB", "S1", "S2", "FIN", "OFF",
               "TRANSF", "keep", "tier", "exclusion_reason", "ML_vocab")]
write.csv(flags, "output/screening_flags.csv", row.names = FALSE)
saveRDS(M[keep, ], "output/M_screened.rds")
cat("\nSaved: output/M_screened.rds (retained records), output/screening_flags.csv,",
    "tables S1-S3, validation files\n")
