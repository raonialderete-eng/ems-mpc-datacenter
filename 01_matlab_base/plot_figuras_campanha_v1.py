"""Rebuild paper Figs 2-4 from campanha_v1 CSV traces (not legacy todos_cenarios MATs)."""
from __future__ import annotations

from pathlib import Path
import csv

HERE = Path(__file__).resolve().parent


def _resolve_dirs():
    if (HERE / "traces_figuras").is_dir() and (HERE / "matlab_base").is_dir():
        return HERE, HERE / "traces_figuras", HERE / "figuras_artigo"
    repo = HERE.parent
    traces = repo / "05_resultados" / "figuras_comparativas" / "traces_campanha_v1"
    figs = repo / "04_artigo" / "ieee_access" / "figuras"
    return repo, traces, figs


ROOT, SRC, OUT = _resolve_dirs()

try:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
except ImportError as exc:
    raise SystemExit("matplotlib is required: pip install matplotlib") from exc


def load_csv(name: str):
    path = SRC / f"{name}.csv"
    cols = {k: [] for k in []}
    with path.open(newline="") as f:
        r = csv.DictReader(f)
        rows = list(r)
    keys = rows[0].keys()
    data = {k: [float(row[k]) for row in rows] for k in keys}
    return data


def style(ax):
    ax.grid(True, alpha=0.35)
    ax.tick_params(labelsize=9)


def three(ax, t, h, m, v, ylab):
    ax.plot(t, h, color="#262626", lw=1.6, label="Heuristic")
    ax.plot(t, m, color="#0072B2", lw=1.6, label="Myopic QP")
    ax.plot(t, v, color="#D55E00", lw=1.6, label="MPC-QP")
    ax.set_ylabel(ylab)
    ax.legend(loc="best", fontsize=8)
    style(ax)


def fig_carga():
    d = load_csv("carga_faixas")
    t = [x / 60.0 for x in d["t_s"]]
    fig, axes = plt.subplots(4, 1, figsize=(8.5, 9.5), sharex=True, constrained_layout=True)
    fig.patch.set_facecolor("white")
    axes[0].plot(t, d["Pload"], color="black", lw=1.6, label=r"$P_{load}$")
    axes[0].plot(t, d["Psource_max"], color="black", lw=1.2, ls="--", label=r"$P_{source,max}$")
    axes[0].set_ylabel("Power [kW]")
    axes[0].set_title("Load bands — Heuristic / Myopic / MPC-QP")
    axes[0].legend(loc="best", fontsize=8)
    style(axes[0])
    three(axes[1], t, d["PBESS_h"], d["PBESS_m"], d["PBESS_v"], r"$P_{BESS}$ [kW]")
    three(axes[2], t, d["Pnao_h"], d["Pnao_m"], d["Pnao_v"], "Unserved power [kW]")
    three(axes[3], t, d["SOC_h"], d["SOC_m"], d["SOC_v"], "SOC [%]")
    axes[3].set_xlabel("Time [min]")
    fig.savefig(OUT / "comp_carga_faixas_paineis.png", dpi=300)
    plt.close(fig)


def fig_limite():
    d = load_csv("limite_fonte")
    n = len(d["t_s"])
    mask = [150 <= d["t_s"][i] <= 350 for i in range(n)]
    t = [d["t_s"][i] / 60.0 for i in range(n) if mask[i]]
    fig, axes = plt.subplots(2, 1, figsize=(8.5, 6.2), sharex=True, constrained_layout=True)
    fig.patch.set_facecolor("white")
    three(
        axes[0],
        t,
        [d["PBESS_h"][i] for i in range(n) if mask[i]],
        [d["PBESS_m"][i] for i in range(n) if mask[i]],
        [d["PBESS_v"][i] for i in range(n) if mask[i]],
        r"$P_{BESS}$ [kW]",
    )
    axes[0].axvline(200 / 60.0, color="black", ls=":", lw=1.2)
    axes[0].set_title("Source limit — step zoom (t = 200 s)")
    three(
        axes[1],
        t,
        [d["Pnao_h"][i] for i in range(n) if mask[i]],
        [d["Pnao_m"][i] for i in range(n) if mask[i]],
        [d["Pnao_v"][i] for i in range(n) if mask[i]],
        "Unserved power [kW]",
    )
    axes[1].axvline(200 / 60.0, color="black", ls=":", lw=1.2)
    axes[1].set_xlabel("Time [min]")
    fig.savefig(OUT / "comp_limite_fonte_zoom_degrau.png", dpi=300)
    plt.close(fig)


def fig_perda():
    d = load_csv("perda_fonte")
    n = len(d["t_s"])
    idx0 = next(i for i in range(n) if d["g"][i] == 0)
    t0 = d["t_s"][idx0]
    t_end = d["t_s"][-1]
    mask = [max(0.0, t0 - 60) <= d["t_s"][i] <= min(t_end, t0 + 180) for i in range(n)]
    t = [d["t_s"][i] / 60.0 for i in range(n) if mask[i]]
    fig, axes = plt.subplots(2, 1, figsize=(8.5, 6.2), sharex=True, constrained_layout=True)
    fig.patch.set_facecolor("white")
    three(
        axes[0],
        t,
        [d["PBESS_h"][i] for i in range(n) if mask[i]],
        [d["PBESS_m"][i] for i in range(n) if mask[i]],
        [d["PBESS_v"][i] for i in range(n) if mask[i]],
        r"$P_{BESS}$ [kW]",
    )
    axes[0].axvline(t0 / 60.0, color="black", ls=":", lw=1.2, label="Source-loss onset")
    axes[0].set_title(f"Source loss — onset zoom (tf = {t0:.0f} s)")
    axes[0].legend(loc="best", fontsize=8)
    three(
        axes[1],
        t,
        [d["Pnao_h"][i] for i in range(n) if mask[i]],
        [d["Pnao_m"][i] for i in range(n) if mask[i]],
        [d["Pnao_v"][i] for i in range(n) if mask[i]],
        "Unserved power [kW]",
    )
    axes[1].axhline(350.0, color="#666666", ls="--", lw=1.0, label="Case-study bound (350 kW)")
    axes[1].axvline(t0 / 60.0, color="black", ls=":", lw=1.2, label="_nolegend_")
    axes[1].legend(loc="best", fontsize=8)
    axes[1].set_xlabel("Time [min]")
    fig.savefig(OUT / "comp_perda_fonte_zoom_falha.png", dpi=300)
    plt.close(fig)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    fig_carga()
    fig_limite()
    fig_perda()
    print("OK", OUT)
