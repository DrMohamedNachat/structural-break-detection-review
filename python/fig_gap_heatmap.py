# Figure: literature density across method families and application domains,
# computed from the corpus (detection stratum). Reads the cross-tabulation written
# by R/07_additional_analyses.R (output/figures/F11_gap_heatmap_data.csv, released
# here as results/tables/X6_gap_heatmap_counts.csv).
#
#   python fig_gap_heatmap.py [path/to/X6_gap_heatmap_counts.csv]
import sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt, pandas as pd, numpy as np

DATA = sys.argv[1] if len(sys.argv) > 1 else "../results/tables/X6_gap_heatmap_counts.csv"

d = pd.read_csv(DATA)
fam_order = ["Classical break tests", "Segmentation algorithms", "Markov / regime switching",
             "Threshold / smooth transition", "Volatility models (GARCH/SV)", "Bayesian",
             "State-space / filtering", "Wavelet / frequency", "Nonparametric / kernel",
             "Machine / deep learning"]
dom_order = list(dict.fromkeys(d["domain"]))
P = d.pivot(index="family", columns="domain", values="share_of_domain_pct").loc[fam_order, dom_order]
N = d.pivot(index="family", columns="domain", values="n").loc[fam_order, dom_order]
tot = d.drop_duplicates("domain").set_index("domain").loc[dom_order, "domain_total"]

fig, ax = plt.subplots(figsize=(11, 6.8))
im = ax.imshow(np.log1p(P.values), cmap="YlOrRd", aspect="auto")
ax.set_xticks(range(len(dom_order)))
ax.set_xticklabels([f"{c}\n(n={tot[c]:,})" for c in dom_order], rotation=35, ha="right", fontsize=8)
ax.set_yticks(range(len(fam_order)))
ax.set_yticklabels(fam_order, fontsize=8.5)
for i in range(len(fam_order)):
    for j in range(len(dom_order)):
        v = P.values[i, j]; k = N.values[i, j]
        ax.text(j, i, f"{v:.1f}%\n({k})", ha="center", va="center", fontsize=6.8,
                color="white" if v > 12 else "black")
ax.add_patch(plt.Rectangle((-0.5, len(fam_order) - 1.5), len(dom_order), 1, fill=False,
                           ls="--", lw=1.5, ec="#c55a11"))
cb = fig.colorbar(im, ax=ax, fraction=0.03, pad=0.02)
cb.set_label("log(1 + share of domain papers, %)", fontsize=8)
ax.set_title("Detection papers mentioning each method family, by application domain "
             "(share of domain papers, count)", fontsize=9)
plt.tight_layout()
plt.savefig("fig_gap_heatmap.pdf")
plt.savefig("fig_gap_heatmap.png", dpi=300)
print("saved fig_gap_heatmap.pdf/.png")
