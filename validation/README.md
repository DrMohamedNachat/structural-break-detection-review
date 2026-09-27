# Coded validation samples

Two things in the analysis are decided by a lexical rule rather than by reading, so
both are checked against samples coded by hand. These are those samples, with the
codes as they were recorded.

## `screening_validation_coded.csv` — do the screening rules pick the right records?

150 records: 75 drawn at random from those the rules retained, 75 from those they
excluded (`set.seed(2026)` in `R/02b_screening.R`). Both coders saw title, source,
year and abstract, and not the rule's decision.

| Column | Meaning |
|---|---|
| `id` | Sample id, `S001`–`S150` |
| `title`, `source`, `year` | The record |
| `rule_retained` | What the rule decided: 1 retained, 0 excluded |
| `stratum` | The stratum the rule assigned |
| `coder1_eligible`, `coder2_eligible` | Human judgement: 1 eligible, 0 not |

All 150 records are coded by both coders. Coder 1 is the reference coder; coder 2 is
used only for inter-coder agreement. Results: precision 0.867, weighted recall 0.911,
agreement 0.853, Cohen's κ 0.691 (`results/tables/V1_screening_validation.csv` and
`V2_intercoder.csv`; the records the two coders read differently are listed in
`V5_disagreements.csv`).

## `ml_tag_validation_coded.csv` — does an ML mention mean ML was used?

All 325 retained records whose title, keywords or abstract mention machine- or
deep-learning vocabulary, read one by one.

| Column | Meaning |
|---|---|
| `uid`, `corpus`, `stratum`, `year`, `title`, `source` | The record |
| `ml_used_for_detection` | 1 if ML performs the detection step itself, 0 if it is only mentioned or used for something else (forecasting, pricing, classification after the fact) |
| `ml_method` | The method, as stated by the record |

**71 of 325** tagged records use ML for detection. This is the gap between the
mention-based shares in `results/tables/T8*` and the validated shares in `V3`/`V4`,
and the reason the review reports both.

## Re-running step 08

`R/08_validation.R` reads these files from `output/`, under the names the pipeline
gives them. Before running it:

```
cp validation/screening_validation_coded.csv output/validation_screening_to_code.csv
cp validation/ml_tag_validation_coded.csv     output/validation_ml_to_code.csv
```

and rename the coder columns back to `coder1_eligible` / `coder2_eligible` (they
already carry those names) and `ML_used_for_detection` / `ML_method`. Step 08 also
reads `output/validation_screening_key.csv`, which `02b` writes.

**One caution.** `R/02b_screening.R` writes these two files as *blank templates*
every time it runs, so re-running the pipeline over a folder that holds coded copies
will overwrite them. Keep the coded files outside `output/`, which is what this
directory is for. Step 08 prefers an `.xlsx` over a `.csv` of the same name, which is
how the coding was originally preserved.

## Abstracts

Removed from both files. The coders worked from abstracts, but those are the
publishers' text and are not redistributable under the licences the records came
from. Every record can be retrieved from its DOI or title.
