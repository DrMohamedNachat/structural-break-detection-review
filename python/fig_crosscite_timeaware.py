# Figure: citation links from corpus A to corpus B by period of the citing paper.
# Left: observed share of links to B and share expected from the size of the citable
# literature up to the citing year. Right: ratio of the two (time-aware ratio).
# 95% intervals from a bootstrap over citing papers. Reads
# X5_crosscite_period_timeaware.csv, written by R/07_additional_analyses.R and
# released as results/tables/.
#
#   python fig_crosscite_timeaware.py [path/to/X5_crosscite_period_timeaware.csv]
import sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt, pandas as pd, numpy as np

DATA = sys.argv[1] if len(sys.argv) > 1 else "../results/tables/X5_crosscite_period_timeaware.csv"

d = pd.read_csv(DATA); x = np.arange(len(d))
fig, axes = plt.subplots(1, 2, figsize=(10, 3.8))
ax = axes[0]
ax.errorbar(x, 100 * d.share_to_B,
            yerr=[100 * (d.share_to_B - d.share_lo), 100 * (d.share_hi - d.share_to_B)],
            fmt="-o", color="#1f4e79", capsize=3, label="Observed share of links to B")
ax.plot(x, 100 * d.expected_share_B, "--s", color="#c55a11", ms=4,
        label="Share of B in citable literature")
ax.set_ylabel("%", fontsize=9)
ax.set_title("Links from corpus A to corpus B", fontsize=10)
ax.legend(fontsize=8, frameon=False)
ax = axes[1]
ax.errorbar(x, d.ratio_time_aware,
            yerr=[d.ratio_time_aware - d.ratio_lo, d.ratio_hi - d.ratio_time_aware],
            fmt="-o", color="#1f4e79", capsize=3)
ax.axhline(1, color="grey", lw=0.8, ls=":"); ax.set_ylim(0, 1.1)
ax.set_title("Observed / expected (time-aware ratio)", fontsize=10)
for a in axes:
    a.set_xticks(x); a.set_xticklabels(d.period, fontsize=9); a.grid(axis="y", alpha=0.3)
    for s in ("top", "right"): a.spines[s].set_visible(False)
fig.supxlabel("Period of the citing paper", fontsize=9)
plt.tight_layout()
plt.savefig("F10_crosscite_timeaware.pdf")
plt.savefig("F10_crosscite_timeaware.png", dpi=300)
print("saved F10_crosscite_timeaware.pdf/.png")
