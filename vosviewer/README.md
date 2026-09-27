# VOSviewer files

Keyword co-occurrence networks, exported in VOSviewer's map/network format by
section 8 of `R/03_bibliometric_analysis.R`.

To open a network in VOSviewer 1.6 or later: **File → Open → VOSviewer map file**,
select the `*_map.txt`, then set **VOSviewer network file** to the matching
`*_network.txt`.

| Pair | Scope | Minimum occurrences |
|---|---|---|
| `kw_all_map.txt` / `kw_all_network.txt` | All 9,111 retained records | 10 |
| `kw_detection_map.txt` / `kw_detection_network.txt` | T1 detection stratum only | 5 |
| `kw_corpusA_map.txt` / `kw_corpusA_network.txt` | Corpus A (economics and business venues) | 10 |
| `kw_corpusB_map.txt` / `kw_corpusB_network.txt` | Corpus B (all other subject areas) | 5 |

`kw_all_clustered.txt` and `kw_detection_clustered.txt` are the two networks with
VOSviewer's cluster assignment saved back, as used for the published figures.

Each map file carries `id`, `label`, `weight` (occurrences) and a
`score<Avg. pub. year>` column — the mean publication year of the records carrying
that keyword, which is what drives the overlay visualisations. Network files are
unlabelled triples `id1  id2  weight`.

**The keywords are already normalised.** The synonym table in
`../data/keyword_synonyms.csv` is applied in R before the export, so do not load a
thesaurus file in VOSviewer on top of these: it would merge terms twice.

The figures produced from these files are in `../results/figures/`
(`F7_cooccurrence_all_*.pdf`, `F7b_cooccurrence_detection_*.pdf`). The equivalent
networks drawn directly in R with igraph, with Louvain communities instead of
VOSviewer clusters, are `F7b_keyword_cooccurrence_all.png` and
`F7c_keyword_cooccurrence_detection.png`, with their community assignments in
`../results/tables/`.
