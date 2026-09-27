# Figure: methodological genealogy of the seven method families.
# Every entry corresponds to a reference in the manuscript bibliography.
# No bubble sizes: citation impact is not encoded (the earlier figure used
# approximate values that could not be verified).
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

families = [
 ("Classical break tests", "#1f4e79", [
   (1960, "Chow test\nChow"), (1975, "CUSUM\nBrown, Durbin, Evans"), (1989, "Unit root with break\nPerron"),
   (1992, "Zivot–Andrews"), (1993, "sup-F\nAndrews"), (1994, "ICSS\nInclán & Tiao"),
   (1996, "Gregory–Hansen"), (1998, "Multiple breaks\nBai & Perron"), (2003, "LM unit root\nLee & Strazicich"),
   (2012, "Fourier breaks\nEnders & Lee"), (2015, "PSY bubbles\nPhillips, Shi, Yu")]),
 ("Segmentation / model selection", "#2e75b6", [
   (1974, "Binary segmentation\nScott & Knott"), (2005, "Penalised contrast\nLavielle"),
   (2012, "PELT\nKillick et al."), (2014, "Wild binary segm.\nFryzlewicz")]),
 ("Markov / regime switching", "#c00000", [
   (1989, "MS-AR\nHamilton"), (1990, "Long swings\nEngel & Hamilton"), (1994, "Time-varying TP\nFilardo"),
   (1996, "MS-GARCH\nGray"), (2004, "MS-GARCH\nHaas et al."), (2007, "MS allocation\nGuidolin & Timmermann")]),
 ("Volatility models", "#548235", [
   (1982, "ARCH\nEngle"), (1982, "SV\nTaylor"), (1986, "GARCH\nBollerslev"), (1993, "Heston"),
   (1998, "MS-SV\nSo, Lam, Li"), (2005, "Breaks in GARCH\nHillebrand")]),
 ("Bayesian / state-space", "#7030a0", [
   (1993, "Product partition\nBarry & Hartigan"), (1994, "MS state-space\nKim"),
   (2007, "BOCPD\nAdams & MacKay"), (2007, "Online multiple CP\nFearnhead & Liu")]),
 ("Nonparametric / kernel / wavelet", "#bf9000", [
   (2001, "Wavelets in finance\nGençay et al."), (2009, "Kernel CPD\nHarchaoui et al."),
   (2012, "MMD\nGretton et al."), (2014, "E-divisive\nMatteson & James"), (2019, "Kernel multiple CP\nArlot et al.")]),
 ("Machine / deep learning", "#c55a11", [
   (1997, "LSTM\nHochreiter & Schmidhuber"), (2015, "VAE anomaly\nAn & Cho"),
   (2021, "TIRE autoencoder\nDe Ryck et al."), (2024, "Learned CP detector\nLi et al."), (2026, "DS3M\nXu et al.")]),
]

fig, ax = plt.subplots(figsize=(15, 11))
n = len(families)
H = 1.6                                   # vertical spacing between family bands
levels = [0.38, -0.38, 0.62, -0.62]      # label offsets (in band units), cycled for close neighbours
for i, (name, col, items) in enumerate(families):
    y = (n - i) * H
    ax.axhspan(y - 0.78, y + 0.78, color=col, alpha=0.07, lw=0)
    last = []                             # (year, level index) of already placed labels
    for yr, lab in sorted(items):
        close = [lv for (py, lv) in last if abs(py - yr) < 5.5]
        lv = next(k for k in range(len(levels)) if k not in close) if len(close) < len(levels) else 0
        last.append((yr, lv))
        off = levels[lv]
        ax.plot(yr, y, "o", color=col, ms=7, zorder=3)
        ax.plot([yr, yr], [y, y + off * 0.8], color=col, lw=0.5, alpha=0.6, zorder=2)
        ax.text(yr, y + off, lab, ha="center", va="center", fontsize=6.3, color="black",
                bbox=dict(boxstyle="round,pad=0.12", fc="white", ec="none", alpha=0.85), zorder=4)
ax.set_yticks([(n - i) * H for i in range(n)])
ax.set_yticklabels([f[0] for f in families], fontsize=9, fontweight="bold")
for t, f in zip(ax.get_yticklabels(), families): t.set_color(f[1])
ax.tick_params(axis="y", length=0)
# cross-family links (dotted)
for (x0, y0, x1, y1) in [(1986, 4, 1996, 5), (1989, 5, 1994, 3), (1975, 7, 2024, 1)]:
    ax.plot([x0, x1], [y0 * H, y1 * H], ls=":", color="grey", lw=0.9, zorder=1)
ax.set_xlim(1955, 2029); ax.set_ylim(H - 0.9, n * H + 0.9)
ax.set_xlabel("Year"); ax.set_xticks(range(1955, 2030, 5))
for s in ("top", "right", "left"): ax.spines[s].set_visible(False)
ax.text(2028.5, H - 0.85, "Dotted lines: cross-family links (GARCH→MS-GARCH, MS-AR→MS state-space, CUSUM→learned detector of Li et al.)",
        ha="right", va="bottom", fontsize=7, style="italic", color="grey")
plt.tight_layout()
plt.savefig("fig_genealogy_timeline.pdf"); plt.savefig("fig_genealogy_timeline.png", dpi=300)
print("saved fig_genealogy_timeline.pdf/.png")
