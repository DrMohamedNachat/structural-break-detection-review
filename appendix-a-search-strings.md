# Appendix A — Search strings

Searches were run in **September 2026** on **Scopus** and the **Web of Science Core
Collection**, covering publications dated **2010–2025**.

Each query combines two blocks with `AND`, both applied to title, author keywords and
abstract:

- **Block 1 — the phenomenon and the named procedures used to detect it.** Change
  point, structural break, structural or parameter instability, regime switching,
  Markov switching, regime change, regime shift, breakpoint, break date, trend break,
  change detection, concept drift, time series segmentation, together with
  Bai–Perron, Chow test, CUSUM, Zivot–Andrews, ICSS, Inclán–Tiao, sup-F, Quandt, PELT
  and binary segmentation. **`structural change` is searched in titles and keywords
  only**, because in abstracts it mostly denotes sectoral transformation.
- **Block 2 — the domain**: financial and macroeconomic series (financial, stock,
  volatility, exchange rate, cryptocurrency, commodity, oil price, interest rate,
  bond yield, credit, inflation, GDP, business cycle, monetary policy, among others).

No method term is imposed, so the searches do not presuppose which family of methods
a study uses.

Each search was run **twice**: once restricted to the economics and business subject
areas, once restricted to their complement. The two runs define corpus A (economics
and business venues) and corpus B (all other venues). Both were limited to
English-language articles, reviews and conference papers.

---

## A.1 Scopus — corpus A

Corpus B uses the same string with `AND NOT SUBJAREA ( ECON OR BUSI )` as last
clause.

```
( TITLE ( "change point*" OR "changepoint*" OR "change-point*" OR "structural break*"
OR "structural change*" OR "structural instabilit*" OR "parameter instabilit*" OR
"regime change*" OR "regime shift*" OR "regime switch*" OR "Markov switch*" OR
"Markov-switch*" OR "breakpoint*" OR "break point*" OR "break date*" OR "trend break*"
OR "change detection" OR "concept drift" OR "time series segmentation" OR "Bai-Perron"
OR "Bai and Perron" OR "Chow test*" OR "CUSUM*" OR "Zivot-Andrews" OR "Zivot and
Andrews" OR "ICSS" OR "Inclan-Tiao" OR "Inclan and Tiao" OR "sup-F" OR "supF" OR
"Quandt" OR "PELT" OR "binary segmentation" ) OR AUTHKEY ( "change point*" OR
"changepoint*" OR "change-point*" OR "structural break*" OR "structural change*" OR
"structural instabilit*" OR "parameter instabilit*" OR "regime change*" OR "regime
shift*" OR "regime switch*" OR "Markov switch*" OR "Markov-switch*" OR "breakpoint*"
OR "break point*" OR "break date*" OR "trend break*" OR "change detection" OR "concept
drift" OR "time series segmentation" OR "Bai-Perron" OR "Bai and Perron" OR "Chow
test*" OR "CUSUM*" OR "Zivot-Andrews" OR "Zivot and Andrews" OR "ICSS" OR
"Inclan-Tiao" OR "Inclan and Tiao" OR "sup-F" OR "supF" OR "Quandt" OR "PELT" OR
"binary segmentation" ) OR ABS ( "change point*" OR "changepoint*" OR "change-point*"
OR "structural break*" OR "structural instabilit*" OR "parameter instabilit*" OR
"regime change*" OR "regime shift*" OR "regime switch*" OR "Markov switch*" OR
"Markov-switch*" OR "breakpoint*" OR "break point*" OR "break date*" OR "trend break*"
OR "change detection" OR "concept drift" OR "time series segmentation" OR "Bai-Perron"
OR "Bai and Perron" OR "Chow test*" OR "CUSUM*" OR "Zivot-Andrews" OR "Zivot and
Andrews" OR "ICSS" OR "Inclan-Tiao" OR "Inclan and Tiao" OR "sup-F" OR "supF" OR
"Quandt" OR "PELT" OR "binary segmentation" ) ) AND ( TITLE ( "financial" OR "finance"
OR "stock*" OR "equity market*" OR "asset price*" OR "asset return*" OR "volatility"
OR "exchange rate*" OR "foreign exchange" OR "currenc*" OR "cryptocurrenc*" OR
"bitcoin" OR "commodit*" OR "oil price*" OR "interest rate*" OR "bond market*" OR
"bond yield*" OR "yield curve" OR "credit" OR "inflation" OR "GDP" OR "macroeconom*"
OR "business cycle*" OR "monetary policy" OR "economic time series" ) OR ABS (
"financial" OR "finance" OR "stock*" OR "equity market*" OR "asset price*" OR "asset
return*" OR "volatility" OR "exchange rate*" OR "foreign exchange" OR "currenc*" OR
"cryptocurrenc*" OR "bitcoin" OR "commodit*" OR "oil price*" OR "interest rate*" OR
"bond market*" OR "bond yield*" OR "yield curve" OR "credit" OR "inflation" OR "GDP"
OR "macroeconom*" OR "business cycle*" OR "monetary policy" OR "economic time series"
) OR AUTHKEY ( "financial" OR "finance" OR "stock*" OR "equity market*" OR "asset
price*" OR "asset return*" OR "volatility" OR "exchange rate*" OR "foreign exchange"
OR "currenc*" OR "cryptocurrenc*" OR "bitcoin" OR "commodit*" OR "oil price*" OR
"interest rate*" OR "bond market*" OR "bond yield*" OR "yield curve" OR "credit" OR
"inflation" OR "GDP" OR "macroeconom*" OR "business cycle*" OR "monetary policy" OR
"economic time series" ) ) ) AND PUBYEAR > 2009 AND PUBYEAR < 2026 AND LANGUAGE (
english ) AND DOCTYPE ( ar OR re OR cp ) AND SUBJAREA ( ECON OR BUSI )
```

Exported as CSV with citation information, bibliographical information, abstract and
keywords, and references, into `Scopus_A.csv` (7,214 records) and `Scopus_B.csv`
(3,986 records).

---

## A.2 Web of Science — corpus A

Corpus B replaces the last clause by `AND NOT SU=("Business & Economics")`.

```
(TI=("change point*" OR "changepoint*" OR "change-point*" OR "structural break*" OR
"structural change*" OR "structural instabilit*" OR "parameter instabilit*" OR "regime
change*" OR "regime shift*" OR "regime switch*" OR "Markov switch*" OR
"Markov-switch*" OR "breakpoint*" OR "break point*" OR "break date*" OR "trend break*"
OR "change detection" OR "concept drift" OR "time series segmentation" OR "Bai-Perron"
OR "Bai and Perron" OR "Chow test*" OR "CUSUM*" OR "Zivot-Andrews" OR "Zivot and
Andrews" OR "ICSS" OR "Inclan-Tiao" OR "Inclan and Tiao" OR "sup-F" OR "supF" OR
"Quandt" OR "PELT" OR "binary segmentation") OR AK=("change point*" OR "changepoint*"
OR "change-point*" OR "structural break*" OR "structural change*" OR "structural
instabilit*" OR "parameter instabilit*" OR "regime change*" OR "regime shift*" OR
"regime switch*" OR "Markov switch*" OR "Markov-switch*" OR "breakpoint*" OR "break
point*" OR "break date*" OR "trend break*" OR "change detection" OR "concept drift" OR
"time series segmentation" OR "Bai-Perron" OR "Bai and Perron" OR "Chow test*" OR
"CUSUM*" OR "Zivot-Andrews" OR "Zivot and Andrews" OR "ICSS" OR "Inclan-Tiao" OR
"Inclan and Tiao" OR "sup-F" OR "supF" OR "Quandt" OR "PELT" OR "binary segmentation")
OR AB=("change point*" OR "changepoint*" OR "change-point*" OR "structural break*" OR
"structural instabilit*" OR "parameter instabilit*" OR "regime change*" OR "regime
shift*" OR "regime switch*" OR "Markov switch*" OR "Markov-switch*" OR "breakpoint*"
OR "break point*" OR "break date*" OR "trend break*" OR "change detection" OR "concept
drift" OR "time series segmentation" OR "Bai-Perron" OR "Bai and Perron" OR "Chow
test*" OR "CUSUM*" OR "Zivot-Andrews" OR "Zivot and Andrews" OR "ICSS" OR
"Inclan-Tiao" OR "Inclan and Tiao" OR "sup-F" OR "supF" OR "Quandt" OR "PELT" OR
"binary segmentation")) AND (TI=("financial" OR "finance" OR "stock*" OR "equity
market*" OR "asset price*" OR "asset return*" OR "volatility" OR "exchange rate*" OR
"foreign exchange" OR "currenc*" OR "cryptocurrenc*" OR "bitcoin" OR "commodit*" OR
"oil price*" OR "interest rate*" OR "bond market*" OR "bond yield*" OR "yield curve"
OR "credit" OR "inflation" OR "GDP" OR "macroeconom*" OR "business cycle*" OR
"monetary policy" OR "economic time series") OR AB=("financial" OR "finance" OR
"stock*" OR "equity market*" OR "asset price*" OR "asset return*" OR "volatility" OR
"exchange rate*" OR "foreign exchange" OR "currenc*" OR "cryptocurrenc*" OR "bitcoin"
OR "commodit*" OR "oil price*" OR "interest rate*" OR "bond market*" OR "bond yield*"
OR "yield curve" OR "credit" OR "inflation" OR "GDP" OR "macroeconom*" OR "business
cycle*" OR "monetary policy" OR "economic time series") OR AK=("financial" OR
"finance" OR "stock*" OR "equity market*" OR "asset price*" OR "asset return*" OR
"volatility" OR "exchange rate*" OR "foreign exchange" OR "currenc*" OR
"cryptocurrenc*" OR "bitcoin" OR "commodit*" OR "oil price*" OR "interest rate*" OR
"bond market*" OR "bond yield*" OR "yield curve" OR "credit" OR "inflation" OR "GDP"
OR "macroeconom*" OR "business cycle*" OR "monetary policy" OR "economic time
series")) AND PY=(2010-2025) AND DT=(Article OR Review OR "Proceedings Paper") AND
LA=(English) AND SU=("Business & Economics")
```

Exported as **"Full Record and Cited References"** in plain text into `Wos_A_01.txt` …
`Wos_A_13.txt` (6,418 records) and `WoS_B_1.txt` … `WoS_B_8.txt` (3,804 records).

The cited references are not optional: `R/04_cross_citation.R` matches the DOIs in the
`CR` field against the corpus DOIs to build the citation links between the two
corpora, and without them that step produces nothing. Web of Science caps a plain-text
export at 500 records, which is why corpus A arrives in thirteen files and corpus B in
eight; `R/01_import_merge.R` globs `^wos_a_.*\.txt$` and `^wos_b_.*\.txt$`
case-insensitively, so the file count does not matter.

---

## What the queries retrieved

| | Web of Science | Scopus |
|---|---|---|
| Corpus A | 6,418 | 7,214 |
| Corpus B | 3,804 | 3,986 |

The A/B label describes the venue as the database classifies it, not the content of
the article. 591 records received different labels in the two databases and were given
the Web of Science label; all of them are listed in
`results/tables/S4_label_discordance.csv`.

After deduplication within each database (8 records within WoS, 5 within Scopus),
across databases (9,231, the Web of Science record kept because it carries the cited
references) and the automatic exclusions — publication year 2026 (161), retracted (7),
residual duplicates differing only in DOI punctuation (10) — **12,000** records entered
the screening. The full chain of counts is `results/tables/S0_prisma_counts.csv`, drawn
as `results/figures/F1_prisma.pdf`.
