# Released data

## `record_level_screening.csv`

One row for each of the 12,000 records that entered the screening, giving the
screening decision and the reason for it. This is the table promised in the article's
data availability statement.

| Column | Meaning |
|---|---|
| `uid` | Stable record key: `doi:<punctuation-free DOI>`, or `ti:<title>\|<year>` when the record has no DOI. Survives any renumbering of the screening IDs. |
| `doi`, `title`, `year`, `source` | Bibliographic identifiers, as written by the database that supplied the retained record |
| `corpus` | `A` (economics and business venues) or `B` (all other subject areas) |
| `source_db` | `WoS`, `Scopus`, or `Both` when the record was found in both and deduplicated |
| `rule_S1_detection_vocab` | Rule R1, detection branch: explicit or contextual detection vocabulary |
| `rule_S2_regime_switching_vocab` | Rule R1, modelling branch: regime-switching vocabulary |
| `rule_R2_financial_term` | A compound financial term is present (checked for corpus B; corpus A satisfies R2 by classification) |
| `rule_R3_off_domain_marker` | An off-domain marker is present in title or author keywords |
| `rule_R4_structural_transformation` | The record belongs to the structural-transformation growth literature |
| `screening_decision_retained` | `TRUE` if all four rules hold |
| `stratum` | `T1a_core_detection`, `T1b_contextual_detection`, `T1c_cusum_stability_diag`, `T2_regime_switching_modelling`, or `excluded` |
| `exclusion_reason` | Which rule failed first, or `retained` |
| `ml_vocabulary_mentioned` | Machine- or deep-learning vocabulary appears in the record. A *mention*, not a validated use — see `validation/` |

Note that `rule_R3_off_domain_marker` and `rule_R4_structural_transformation` are
`TRUE` when the marker is *present*; a record is excluded on R3 only if the marker is
present **and** the title carries no strong financial-market term, which is why some
records with `rule_R3_off_domain_marker = TRUE` are still retained.

## `keyword_synonyms.csv`

The thesaurus applied to author keywords before counting and before building the
co-occurrence networks: 94 variant → canonical mappings, so that
`regime-switching`, `regime switching model` and `regime switching models` all count
as `regime switching`. Applied in R rather than inside VOSviewer, which is why the
VOSviewer files in `vosviewer/` are already normalised.

This table is the authoritative copy; the same mapping is embedded in
`R/03_bibliometric_analysis.R` as the `kw_synonyms` vector. If you extend one, extend
both.

## What is not here

The raw Scopus and Web of Science exports, the merged `bibliometrix` data frames
(`M_merged.rds`, `M_screened.rds`, `M_tagged.rds`, `W_wos.rds`) and all abstracts.
These are covered by the institutional licences under which the records were
retrieved and cannot be redistributed. Re-running the searches in
`../appendix-a-search-strings.md` regenerates them.
