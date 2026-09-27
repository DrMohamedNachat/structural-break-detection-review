# =============================================================================
# 06_prisma_figure.R
# PRISMA-style flow diagram of the search
#
# Reads the counts written by 01_import_merge.R (output/prisma_counts.csv) and
# 02b_screening.R (output/tables/S1_screening_counts.csv) and draws the diagram
# with ggplot2 only (no DiagrammeR / webshot). Edit the box texts if the
# wording of the paper changes; the numbers are never typed by hand.
#
# Output: output/figures/F1_prisma.png / .pdf
# =============================================================================
suppressMessages({ library(ggplot2) })
pc <- read.csv("output/prisma_counts.csv", stringsAsFactors = FALSE)
sc <- read.csv("output/tables/S1_screening_counts.csv", stringsAsFactors = FALSE)
g <- function(tab, key, exact = FALSE) {
  st <- trimws(tab$step)
  v <- if (exact) tab$n[st == key] else tab$n[grepl(key, st, fixed = TRUE)]
  if (length(v) == 0) NA else v[1]
}
fmt <- function(x) format(x, big.mark = ",")

n_wosA <- g(pc, "WoS corpus A"); n_wosB <- g(pc, "WoS corpus B")
n_scoA <- g(pc, "Scopus corpus A"); n_scoB <- g(pc, "Scopus corpus B")
n_dupW <- g(pc, "Duplicates inside WoS"); n_dupS <- g(pc, "Duplicates inside Scopus")
n_cross <- g(pc, "WoS-Scopus duplicates"); n_merged <- g(pc, "Merged unique records")
n_2026 <- g(pc, "final publication year >"); n_retr <- g(pc, "retracted")
n_auto <- g(pc, "Records retained after automatic exclusions")
n_resid <- g(sc, "Residual duplicates"); if (is.na(n_resid)) n_resid <- 0
n_scr <- g(sc, "Records screened"); n_e1 <- g(sc, "no detection"); n_e2 <- g(sc, "no financial")
n_e3 <- g(sc, "off-domain"); n_e4 <- g(sc, "structural-transformation"); n_keep <- g(sc, "Records retained")
n_A <- g(sc, "corpus A", exact = TRUE); n_B <- g(sc, "corpus B", exact = TRUE)
n_T1 <- g(sc, "T1a") + g(sc, "T1b") + g(sc, "T1c"); n_T2 <- g(sc, "T2 ")

boxes <- data.frame(
  id = c("wos", "sco", "dedup", "merged", "auto", "screen", "excl", "keep", "strata"),
  x  = c(2.2, 6.8, 4.5, 4.5, 4.5, 4.0, 9.1, 4.5, 4.5),
  y  = c(10, 10, 8.4, 7.0, 5.6, 4.2, 4.2, 2.6, 1.1),
  w  = c(4.0, 4.0, 5.2, 5.2, 5.2, 4.6, 3.6, 5.2, 6.2),
  h  = c(1.1, 1.1, 1.0, 0.9, 1.0, 1.0, 1.7, 0.9, 1.0),
  label = c(
    sprintf("Web of Science (n = %s)\ncorpus A: %s   corpus B: %s", fmt(n_wosA + n_wosB), fmt(n_wosA), fmt(n_wosB)),
    sprintf("Scopus (n = %s)\ncorpus A: %s   corpus B: %s", fmt(n_scoA + n_scoB), fmt(n_scoA), fmt(n_scoB)),
    sprintf("Duplicates removed: within WoS %s, within Scopus %s,\nacross databases %s (DOI, then title + year)", fmt(n_dupW), fmt(n_dupS), fmt(n_cross)),
    sprintf("Unique records (n = %s)", fmt(n_merged)),
    sprintf("Excluded: publication year 2026 (%s), retracted (%s)\nRecords after automatic exclusions (n = %s)", fmt(n_2026), fmt(n_retr), fmt(n_auto)),
    sprintf("Records screened by rule on title,\nkeywords and abstract (n = %s)", fmt(n_scr)),
    sprintf("Excluded (n = %s)\nno detection / regime term: %s\nno financial term (corpus B): %s\noff-domain marker: %s\nstructural-transformation: %s",
            fmt(n_e1 + n_e2 + n_e3 + n_e4), fmt(n_e1), fmt(n_e2), fmt(n_e3), fmt(n_e4)),
    sprintf("Records retained (n = %s)\ncorpus A: %s   corpus B: %s", fmt(n_keep), fmt(n_A), fmt(n_B)),
    sprintf("Strata: T1 detection of breaks / change points (n = %s)\nT2 regime-switching modelling (n = %s)", fmt(n_T1), fmt(n_T2))),
  stringsAsFactors = FALSE)
if (n_resid > 0) boxes$label[boxes$id == "screen"] <- sprintf("Residual duplicates removed (%s)\nRecords screened by rule on title,\nkeywords and abstract (n = %s)", fmt(n_resid), fmt(n_scr))
boxes$fill <- ifelse(boxes$id %in% c("wos", "sco"), "#dbe7f3", ifelse(boxes$id == "excl", "#fbe5d6", ifelse(boxes$id == "strata", "#e2efda", "#f2f2f2")))

arrows <- data.frame(
  x = c(2.2, 6.8, 4.5, 4.5, 4.5, 4.5, 6.3, 4.5),
  y = c(9.45, 9.45, 7.9, 6.55, 5.1, 3.7, 4.2, 2.15),
  xend = c(4.0, 5.0, 4.5, 4.5, 4.5, 4.5, 7.3, 4.5),
  yend = c(8.9, 8.9, 7.45, 6.1, 4.7, 3.05, 4.2, 1.6))

p <- ggplot() +
  geom_rect(data = boxes, aes(xmin = x - w / 2, xmax = x + w / 2, ymin = y - h / 2, ymax = y + h / 2, fill = fill),
            colour = "grey30", linewidth = 0.4) +
  scale_fill_identity() +
  geom_text(data = boxes, aes(x, y, label = label), size = 2.7, lineheight = 0.95) +
  geom_segment(data = arrows, aes(x = x, y = y, xend = xend, yend = yend),
               arrow = arrow(length = unit(0.18, "cm"), type = "closed"), colour = "grey30", linewidth = 0.4) +
  annotate("text", x = -0.2, y = c(10, 7.0, 4.2, 1.85), label = c("Identification", "Merging", "Screening", "Included"),
           angle = 90, size = 3.2, fontface = "bold", colour = "grey30") +
  coord_cartesian(xlim = c(-0.6, 11.0), ylim = c(0.4, 10.7)) + theme_void()
ggsave("output/figures/F1_prisma.png", p, width = 9, height = 8, dpi = 300, bg = "white")
ggsave("output/figures/F1_prisma.pdf", p, width = 9, height = 8, bg = "white")
cat("Saved output/figures/F1_prisma.png/.pdf\n")
