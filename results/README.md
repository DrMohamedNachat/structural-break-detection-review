# Results

Everything the pipeline writes: 57 tables and 27 figures. Each file is regenerated
from scratch by the script named below, so nothing here is edited by hand.

## Tables

| Prefix | Written by | Contents |
|---|---|---|
| `S0`–`S4` | 01, 02b | PRISMA counts, screening counts, strata, ML share by period, A/B label discordance |
| `T1`–`T2c` | 03 | Main information; annual production overall, by stratum, and its growth rate |
| `T3`–`T5b` | 03 | Top sources, authors, countries, country collaboration, most cited documents |
| `T6`–`T6c` | 03 | Author keywords after synonym normalisation; exact ML/DL keyword counts |
| `T7`–`T9b` | 03 | Method-family prevalence with Wilson intervals; ML share by year; sensitivity without regime-switching terms |
| `T10a`–`T10e` | 04 | Cross-citation: coverage, link matrix against both benchmarks, paper level, links to ML papers, evolution |
| `T11a`–`T11d` | 05 | The first version of the search: correction, mapping onto the revised corpus, recall, ML keyword counts |
| `V1`–`V5` | 08 | Screening precision and recall, inter-coder agreement, ML census, validated share, disagreements |
| `X1`–`X10` | 07 | Corpus B split into B1/B2, families by sub-corpus, cross-citation detail with bootstrap intervals, gap heatmap counts, document types, sensitivities |
| `F7b`/`F7c` `_communities` | 03 | Louvain community assignment of the keyword co-occurrence networks |

`S0_prisma_counts.csv` and `S4_label_discordance.csv` are the pipeline's
`prisma_counts.csv` and `label_discordance.csv`, renamed here so that the whole
directory sorts in reading order.

## Figures

| File | Written by | Contents |
|---|---|---|
| `F1_prisma` | 06 | PRISMA flow diagram, with every count read from `S0` and `S1` |
| `F2`, `F2b` | 03 | Annual production, overall and by stratum |
| `F3_top_authors` | 03 | Fifteen most productive authors |
| `F4_world_map` | 03 | Publications and citations by country |
| `F5_country_collaboration_heatmap` | 03 | Co-authorship between the top 20 countries |
| `F7_method_families` | 03 | Family prevalence by corpus and stratum, with Wilson intervals |
| `F7b`, `F7c` `_keyword_cooccurrence` | 03 | Keyword co-occurrence networks drawn in R, coloured by Louvain community |
| `F8_ml_share_by_year_detection` | 03 | ML/DL share per year among detection papers |
| `F10_cross_citation_over_time` | 04 | Share of citation links going to the other corpus, by period |
| `fig_gap_heatmap` | `python/fig_gap_heatmap.py` | Method family × application domain density, from `X6` |
| `fig_genealogy_timeline` | `python/fig_genealogy_timeline.py` | Methodological genealogy of the seven families |

`F7_cooccurrence_all_network.pdf`, `F7_cooccurrence_all_overlay.pdf` and their
`F7b_cooccurrence_detection_*` counterparts are the **VOSviewer** renderings, laid out
in the VOSviewer application from the map and network files in `../vosviewer/`. They
are the only figures here not produced by a script; the R versions of the same
networks are the `F7b`/`F7c_keyword_cooccurrence` PNGs.

`F8_three_field_plot.html` (countries → keywords → sources, from step 03) is not
committed: it is a self-contained plotly widget that vendors about 4 MB of JavaScript.
Running step 03 regenerates it in `output/figures/`.

## Reading the method-family tables

The family columns in `T7*`, `X2` and the gap heatmap count whether a family is
**mentioned** in a record's title, abstract or author keywords. They do not establish
that the family is the method the paper uses. For machine learning specifically, all
325 mentioning records were read one by one, and 71 turned out to use ML for the
detection step itself; `V3_ml_census.csv` and `V4_ml_validated_share.csv` carry that
stricter figure, and `../validation/` carries the codes behind it. Where a claim in
the article rests on ML prevalence, the validated number is the one to quote.
