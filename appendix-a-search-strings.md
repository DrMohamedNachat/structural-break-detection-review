# Appendix A — Search strings

> **⚠ TO BE COMPLETED BEFORE PUBLISHING THIS REPOSITORY.**
> The four query strings below are the only part of the replication material that
> could not be recovered from the project folder: they live in the manuscript's
> Appendix A, not in the code. Paste each one in verbatim, exactly as submitted to
> the database, then delete this note.
>
> Nothing else in this repository depends on them being present, but without them the
> corpus cannot be rebuilt, so the repository is not yet complete.

Searches were run on **Scopus** and **Web of Science Core Collection**. Both were
split into two corpora by the database's own subject classification, so that the
economics and business literature (corpus A) can be compared with the literature in
every other field (corpus B) without either query having to guess at venue lists.

Filters applied in all four searches: publication years **2010–2025**, language
**English**. Records with a final publication year of 2026 and retracted publications
are removed in `R/01_import_merge.R` rather than by the query, so that the counts
appear in the PRISMA diagram.

## A.1 Web of Science — corpus A (Business & Economics)

Exported as plain text (full record with cited references) into `Wos_A_01.txt` …
`Wos_A_13.txt`; 6,418 records.

```
<PASTE THE WEB OF SCIENCE QUERY FOR CORPUS A HERE>
```

## A.2 Web of Science — corpus B (all other research areas)

Exported as plain text (full record with cited references) into `WoS_B_1.txt` …
`WoS_B_8.txt`; 3,804 records.

```
<PASTE THE WEB OF SCIENCE QUERY FOR CORPUS B HERE>
```

## A.3 Scopus — corpus A (SUBJAREA ECON or BUSI)

Exported as CSV with abstracts, keywords and references into `Scopus_A.csv`;
7,214 records.

```
<PASTE THE SCOPUS QUERY FOR CORPUS A HERE>
```

## A.4 Scopus — corpus B (NOT SUBJAREA ECON or BUSI)

Exported as CSV with abstracts, keywords and references into `Scopus_B.csv`;
3,986 records.

```
<PASTE THE SCOPUS QUERY FOR CORPUS B HERE>
```

## Export settings

The Web of Science exports must be **"Full Record and Cited References"** in plain
text. `R/04_cross_citation.R` matches the DOIs in the `CR` field against the corpus
DOIs to build the citation links between the two corpora; without cited references
that step produces nothing. Web of Science caps a plain-text export at 500 records,
which is why corpus A arrives in thirteen files and corpus B in eight —
`R/01_import_merge.R` globs `^wos_a_.*\.txt$` and `^wos_b_.*\.txt$`
case-insensitively, so the file count does not matter.

Scopus exports need **Citation information, Bibliographical information, Abstract &
keywords** and **References** ticked.

## What the queries retrieved

| | Web of Science | Scopus |
|---|---|---|
| Corpus A | 6,418 | 7,214 |
| Corpus B | 3,804 | 3,986 |

After deduplication within each database (8 and 5 records), across databases
(9,231 records found in both, the Web of Science version kept) and the automatic
exclusions, **12,000** records entered the screening. The full chain of counts is
`results/tables/S0_prisma_counts.csv`, drawn as `results/figures/F1_prisma.pdf`.

591 records carry a different corpus label in the two databases; the Web of Science
label is kept, and all of them are listed in
`results/tables/S4_label_discordance.csv`.
