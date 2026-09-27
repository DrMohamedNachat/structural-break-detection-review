# Figure: ML/DL in detection papers by sub-corpus (A, B1, B2) and period:
# share mentioning an ML method and share validated as using ML for detection,
# with 95% Wilson intervals. Reads X3_ml_by_subcorpus_period.csv, written by
# R/07_additional_analyses.R and released as results/tables/.
#
#   python fig_ml_share_subcorpus.py [path/to/X3_ml_by_subcorpus_period.csv]
import sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt, pandas as pd, numpy as np

DATA = sys.argv[1] if len(sys.argv) > 1 else "../results/tables/X3_ml_by_subcorpus_period.csv"


def wilson(x, n, z=1.96):
    p = x / n; den = 1 + z**2 / n
    c = (p + z**2 / (2 * n)) / den; h = z * np.sqrt(p * (1 - p) / n + z**2 / (4 * n**2)) / den
    return 100 * p, 100 * np.maximum(0, c - h), 100 * np.minimum(1, c + h)


d = pd.read_csv(DATA); d = d[d.period != "all"]
periods = ["2010-2014", "2015-2019", "2020-2022", "2023-2025"]
subs = [("A", "A: economics & business venues", "#1f4e79"),
        ("B1", "B1: mathematics, statistics, CS, physics venues", "#c55a11"),
        ("B2", "B2: energy, environment & other venues", "#7f7f7f")]
fig, axes = plt.subplots(1, 2, figsize=(11, 4.2), sharex=True)
for ax, col, title in [(axes[0], "mention", "Mention of an ML/DL method"),
                       (axes[1], "validated", "ML/DL used for detection (validated)")]:
    for k, (s, lab, c) in enumerate(subs):
        g = d[d["sub"] == s].set_index("period").loc[periods]
        p, lo, hi = wilson(g[col].values.astype(float), g["n"].values.astype(float))
        x = np.arange(len(periods)) + (k - 1) * 0.08
        ax.errorbar(x, p, yerr=[np.clip(p - lo, 0, None), np.clip(hi - p, 0, None)],
                    fmt="-o", color=c, ms=4, lw=1.4, capsize=3, label=lab)
    ax.set_title(title, fontsize=10); ax.set_xticks(range(len(periods)))
    ax.set_xticklabels(periods, fontsize=9)
    ax.set_ylabel("Share of detection papers (%)", fontsize=9); ax.grid(axis="y", alpha=0.3)
    for s in ("top", "right"): ax.spines[s].set_visible(False)
axes[0].legend(fontsize=8, frameon=False, loc="upper left")
plt.tight_layout()
plt.savefig("F8_ml_share_subcorpus.pdf")
plt.savefig("F8_ml_share_subcorpus.png", dpi=300)
print("saved F8_ml_share_subcorpus.pdf/.png")
