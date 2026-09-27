# From Regime Switching to Machine Learning?

Replication material for **"From Regime Switching to Machine Learning? A Bibliometric
and Systematic Review of Structural Break Detection in Financial Time Series"**.

The review asks whether the literature on detecting structural breaks, change points
and regime changes in financial and economic time series has shifted from
econometric regime-switching models towards machine learning, and whether the two
research communities that work on the problem read each other. Two corpora are
retrieved and analysed separately:

| Corpus | Definition | Retained records |
|---|---|---|
| **A** | Economics and business venues (WoS *Business & Economics*; Scopus ECON or BUSI) | 6,576 |
| **B** | All other subject areas — statistics, computer science, engineering, energy, environment | 2,535 |

Records are then stratified by what they actually do, which is the distinction the
review turns on:

| Stratum | Meaning | n |
|---|---|---|
| T1a | Explicit detection vocabulary (change point, structural break, Bai–Perron, …) | 4,253 |
| T1b | Contextual detection vocabulary (CUSUM, breakpoint, … with a test context) | 698 |
| T1c | CUSUM used only as an ARDL stability diagnostic | 61 |
| T2 | Regime-switching *modelling* without detection vocabulary | 4,099 |

## What is in this repository

```
appendix-a-search-strings.md   the Scopus and Web of Science queries
R/                             the analysis pipeline, 01 to 09
python/                        the two figure scripts (genealogy, gap heatmap)
data/                          keyword synonym table; per-record screening decisions
validation/                    the coded validation samples
vosviewer/                     keyword co-occurrence maps and networks
results/                       every table and figure the pipeline produces
```

## What is *not* in this repository

The bibliometric records themselves. They were retrieved from Scopus and Web of
Science under an institutional licence that does not permit redistribution, so the
raw exports (`Wos_A_*.txt`, `WoS_B_*.txt`, `Scopus_A.csv`, `Scopus_B.csv`) and the
intermediate `.rds` objects are absent.

What is released instead is everything needed to reproduce the corpus and to check
every decision taken on it: the exact search strings, the screening rules as code,
and a row for each of the 12,000 screened records giving its DOI, corpus label,
stratum and screening decision (`data/record_level_screening.csv`). Abstracts have
been removed from every released file for the same licensing reason; titles, journal
names, years and DOIs are kept so that any record can be looked up.

The record-by-record output of step 09 is also absent. That step narrows the corpus
to the studies that propose or evaluate a detection method and draws the sample for
double coding, both of which carry abstracts by construction — the coders work from
them. Running step 09 on your own exports regenerates both files.

## Reproducing the analysis

Run the searches in `appendix-a-search-strings.md`, export the results into a project
folder, and from that folder:

```r
source("R/00_run_all.R")
```

Steps 01–07 and 09 run unattended. Step 08 validates the screening rules against
samples coded by hand; on a fresh run those samples are still blank templates, so
the step reports that it is skipping and the pipeline continues. To reproduce the
published validation numbers, copy the coded files from `validation/` into `output/`
first — see [validation/README.md](validation/README.md).

Tested with **R 4.3.3**, **bibliometrix 5.5.0**, dplyr, tidyr, ggplot2. `maps`,
`ggrepel`, `igraph`, `readxl` and `htmlwidgets` are optional: the steps that need
them are wrapped so that a missing package skips one figure instead of stopping the
run. The Python figures need `matplotlib`, `pandas` and `numpy`
(`pip install -r python/requirements.txt`).

### The pipeline

| Script | What it does | Main output |
|---|---|---|
| `01_import_merge.R` | Import, deduplicate within and across databases, exclude 2026 and retracted records | `M_merged.rds`, PRISMA counts |
| `02b_screening.R` | Rule-based eligibility screening of both corpora, strata, validation samples | `M_screened.rds`, S1–S3 |
| `03_bibliometric_analysis.R` | Production, sources, countries, keywords, method families, VOSviewer files | T1–T9, F2–F8 |
| `04_cross_citation.R` | Citation links between corpora A and B against size-based and time-aware benchmarks | T10a–T10e, F10 |
| `05_original_corpus_comparison.R` | What the first version of the search captured and what the revised corpus adds | T11a–T11d |
| `06_prisma_figure.R` | PRISMA flow diagram, drawn from the recorded counts | F1 |
| `07_additional_analyses.R` | B split into B1/B2, cross-citation detail, gap heatmap, sensitivities | X1–X10 |
| `08_validation.R` | Precision, stratified recall, inter-coder agreement, ML-tag census | V1–V5 |
| `09_screening_candidates.R` | Narrows the corpus to the studies that propose or evaluate a detection method, and draws the double-coding sample | `screening/` |

No number in any figure or table is typed by hand: the PRISMA boxes and the figure
labels all read the counts written by earlier steps.

## How records were screened

A record is retained if all four rules hold. Every rule is lexical and applies to
title, author keywords and abstract, so the whole screening is reproducible from the
code in `R/02b_screening.R`:

- **R1** — detection vocabulary (change point, structural break, Bai–Perron, …) or
  regime-switching vocabulary. Ambiguous terms (CUSUM, ICSS, PELT, breakpoint,
  structural change, change detection, concept drift, regime shift) count only with
  a detection or testing context in the same record.
- **R2** — financial or macroeconomic time series. Automatically satisfied for
  corpus A by the database's own subject classification; for corpus B a compound
  financial term is required, so "stock market" qualifies and "stock" alone does not.
- **R3** — no off-domain marker (remote sensing, ecology, clinical, genomics, …) in
  title or author keywords, unless the title itself carries a strong
  financial-market term.
- **R4** — not the structural-transformation growth literature, which uses
  "structural change" in the sectoral sense.

Of 12,000 screened records, 9,111 were retained and 2,889 excluded: 1,851 for no
detection or regime term, 866 for no financial term, 99 for an off-domain marker and
73 as structural-transformation literature.

### How the rules were checked

On a sample of 150 records — 75 drawn at random from the retained side and 75 from
the excluded side — coded blind by two coders, the rules reach a precision of
**0.867** (95 % CI 0.787–0.933) and a recall of **0.911** (0.880–0.943). Recall is
weighted by the size of the two strata (9,111 retained, 2,889 excluded), since the
sample over-represents the excluded side; intervals come from a stratified bootstrap
with 5,000 resamples. Inter-coder agreement is 0.853, Cohen's κ = **0.691**. The ML
vocabulary tag was checked by reading all 325 tagged records: **71** of them use
machine learning for the detection step itself, the rest only mention it. Both
coded samples are in `validation/`, with the raw counts in `results/tables/V1`–`V5`.

This matters for how the tables should be read: the method-family columns measure
whether a family is **mentioned** in a record, not whether it is the method used.
The validated ML census in `V3`/`V4` is the stricter figure.

## Licence

Code (`R/`, `python/`) under the [MIT licence](LICENSE). Released data, tables and
figures (`data/`, `validation/`, `vosviewer/`, `results/`) under
[CC BY 4.0](LICENSE-data). The underlying bibliographic records remain the
property of Clarivate (Web of Science) and Elsevier (Scopus) and are not
redistributed here.

## Citation

See [CITATION.cff](CITATION.cff).
