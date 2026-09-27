# =============================================================================
# 08_validation.R
# Validation of the screening rules and of the ML tag
#
# Input : output/validation_screening_to_code.xlsx (or .csv) coded by two coders
#         output/validation_screening_key.csv       rule decision for each ID
#         output/validation_ml_to_code.csv          325 ML-tagged records, coded
#         output/tables/T8b_ml_share_by_period_detection.csv (from 03)
# Output: output/tables/V1_screening_validation.csv   precision, weighted recall, CIs
#         output/tables/V2_intercoder.csv             agreement and Cohen's kappa
#         output/tables/V3_ml_census.csv              validated ML use, by corpus/stratum/period
#         output/tables/V4_ml_validated_share.csv     validated ML-detection share of all T1 papers
#         output/tables/V5_disagreements.csv          records on which the coders disagree
#
# Coder 1 is the reference coder (authors' decision); coder 2 is used for the
# inter-coder agreement only.
#
# Recall is computed with stratification weights: the sample holds 75 retained
# and 75 excluded records, drawn from strata of N_ret and N_exc records.
#   precision = P(eligible | retained)
#   recall    = N_ret * p_ret / (N_ret * p_ret + N_exc * p_exc)
# where p_ret and p_exc are the eligible proportions in the two sub-samples.
# 95% intervals by stratified bootstrap (5,000 resamples).
# =============================================================================
suppressMessages({ library(dplyr) })
set.seed(2026)
N_RET <- 9111; N_EXC <- 2889; B <- 5000
dir.create("output/tables", showWarnings = FALSE, recursive = TRUE)

# ---- 1. Read the coded files ---------------------------------------------------
read_coded <- function(stem) {
  x <- paste0("output/", stem, ".xlsx"); c <- paste0("output/", stem, ".csv")
  if (file.exists(x)) { if (!requireNamespace("readxl", quietly = TRUE)) stop("install.packages('readxl')")
    as.data.frame(readxl::read_excel(x)) } else read.csv(c, stringsAsFactors = FALSE)
}
S <- read_coded("validation_screening_to_code")
K <- read.csv("output/validation_screening_key.csv", stringsAsFactors = FALSE)
V <- merge(S, K, by = "ID")
stopifnot(nrow(V) == 150)
V$c1 <- as.integer(V$coder1_eligible)
V$c2 <- if ("coder2_eligible" %in% names(V)) suppressWarnings(as.integer(V$coder2_eligible)) else NA_integer_

# ---- 2. Precision and stratified recall (coder 1) --------------------------------
est <- function(r, e) { p_ret <- mean(r); p_exc <- mean(e)
  c(precision = p_ret, recall = N_RET * p_ret / (N_RET * p_ret + N_EXC * p_exc), p_exc = p_exc) }
val <- function(col) {
  r <- V[[col]][V$rule_retained == 1]; e <- V[[col]][V$rule_retained == 0]
  r <- r[!is.na(r)]; e <- e[!is.na(e)]
  pt <- est(r, e)
  bs <- t(replicate(B, est(sample(r, replace = TRUE), sample(e, replace = TRUE))[1:2]))
  ci <- apply(bs, 2, quantile, c(0.025, 0.975))
  data.frame(coder = col, n_retained = length(r), n_excluded = length(e),
             precision = pt["precision"], precision_lo = ci[1, 1], precision_hi = ci[2, 1],
             recall = pt["recall"], recall_lo = ci[1, 2], recall_hi = ci[2, 2],
             eligible_among_excluded = pt["p_exc"], row.names = NULL)
}
V1 <- val("c1"); if (!all(is.na(V$c2))) V1 <- rbind(V1, val("c2"))
V1[, -1] <- round(V1[, -1], 3)
write.csv(V1, "output/tables/V1_screening_validation.csv", row.names = FALSE); print(V1)

# ---- 3. Inter-coder agreement -------------------------------------------------------
if (!all(is.na(V$c2))) {
  ok <- !is.na(V$c1) & !is.na(V$c2); a <- V$c1[ok]; b <- V$c2[ok]
  po <- mean(a == b); pe <- mean(a == 1) * mean(b == 1) + mean(a == 0) * mean(b == 0)
  kappa <- (po - pe) / (1 - pe)
  V2 <- data.frame(n = sum(ok), agreement = round(po, 3), kappa = round(kappa, 3),
                   both_eligible = sum(a == 1 & b == 1), both_ineligible = sum(a == 0 & b == 0),
                   c1_only = sum(a == 1 & b == 0), c2_only = sum(a == 0 & b == 1))
  write.csv(V2, "output/tables/V2_intercoder.csv", row.names = FALSE); print(V2)
  write.csv(V[V$c1 != V$c2 & ok, c("ID", "TI", "SO", "PY", "rule_retained", "tier", "c1", "c2")],
            "output/tables/V5_disagreements.csv", row.names = FALSE)
}
# Coder-1 eligibility by stratum of the rule (retained records)
print(table(rule = V$tier, coder1 = V$c1))

# ---- 4. Census of the ML-tagged records ----------------------------------------------
M <- read.csv("output/validation_ml_to_code.csv", stringsAsFactors = FALSE)
M$use <- as.integer(M$ML_used_for_detection); stopifnot(!any(is.na(M$use)))
M$stratum <- ifelse(grepl("^T1", M$tier), "T1 detection", "T2 modelling")
M$period <- cut(as.numeric(M$PY), c(2009, 2014, 2019, 2022, 2025),
                labels = c("2010-2014", "2015-2019", "2020-2022", "2023-2025"))
wilson <- function(x, n, z = 1.96) { p <- x / n; den <- 1 + z^2 / n
  c(share = p, lo = max(0, (p + z^2/(2*n))/den - z*sqrt(p*(1-p)/n + z^2/(4*n^2))/den),
    hi = min(1, (p + z^2/(2*n))/den + z*sqrt(p*(1-p)/n + z^2/(4*n^2))/den)) }
V3 <- bind_rows(
  M %>% group_by(CORPUS, stratum) %>% summarise(tagged = n(), validated = sum(use), .groups = "drop") %>% mutate(period = "all"),
  M %>% group_by(CORPUS, stratum, period) %>% summarise(tagged = n(), validated = sum(use), .groups = "drop") %>% mutate(period = as.character(period))
) %>% mutate(share_of_tagged = round(validated / tagged, 3))
write.csv(V3, "output/tables/V3_ml_census.csv", row.names = FALSE); print(as.data.frame(V3))
cat(sprintf("\nML used for detection: %d of %d tagged records (%.1f%%)\n", sum(M$use), nrow(M), 100 * mean(M$use)))

# ---- 5. Validated ML-detection share among ALL detection papers ------------------------
T8 <- read.csv("output/tables/T8b_ml_share_by_period_detection.csv", stringsAsFactors = FALSE)
det <- M %>% filter(stratum == "T1 detection") %>% group_by(period, CORPUS) %>%
  summarise(validated = sum(use), .groups = "drop") %>% mutate(period = as.character(period))
V4 <- T8 %>% select(period, CORPUS, n, x) %>% rename(n_detection = n, mentions = x) %>%
  left_join(det, by = c("period", "CORPUS")) %>% mutate(validated = coalesce(validated, 0L)) %>%
  rowwise() %>% mutate(mention_share = round(mentions / n_detection, 4),
                       validated_share = round(validated / n_detection, 4),
                       v_lo = round(wilson(validated, n_detection)["lo"], 4),
                       v_hi = round(wilson(validated, n_detection)["hi"], 4)) %>% ungroup()
tot <- V4 %>% group_by(CORPUS) %>% summarise(period = "all", n_detection = sum(n_detection), mentions = sum(mentions),
                                             validated = sum(validated), .groups = "drop") %>%
  rowwise() %>% mutate(mention_share = round(mentions / n_detection, 4), validated_share = round(validated / n_detection, 4),
                       v_lo = round(wilson(validated, n_detection)["lo"], 4), v_hi = round(wilson(validated, n_detection)["hi"], 4)) %>% ungroup()
V4 <- bind_rows(V4, tot)
write.csv(V4, "output/tables/V4_ml_validated_share.csv", row.names = FALSE); print(as.data.frame(V4))
cat("\nSaved V1-V5 in output/tables\n")
