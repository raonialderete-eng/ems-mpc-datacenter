"""Replica PC (sem gcc) de planta + heuristico, para conferir o C no lab."""
from __future__ import annotations

import csv
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "05_resultados" / "hil_de2115"
OUT.mkdir(parents=True, exist_ok=True)


class P:
    Ts = 1.0
    Tf = 1200.0
    Psource_max_nominal = 800.0
    Pload_base, Pload_media, Pload_alta = 600.0, 750.0, 950.0
    Ebat = 500.0
    SOC_min, SOC_max, SOC_ref = 20.0, 90.0, 60.0
    PBESS_max, PBESS_min = 400.0, -250.0
    tau_b = 2.0
    ab = math.exp(-Ts / tau_b)
    bb = 1.0 - ab
    eta_d = eta_c = 0.95
    Nprep = 12
    dUmax, dUmax_evt = 120.0, 400.0


def gera(tipo: str):
    n = int(P.Tf / P.Ts) + 1
    t = [i * P.Ts for i in range(n)]
    load = [P.Pload_base] * n
    pmax = [P.Psource_max_nominal] * n
    grid = [1] * n
    if tipo == "carga_faixas":
        for i, ti in enumerate(t):
            if ti < 200:
                load[i] = P.Pload_base
            elif ti < 400:
                load[i] = P.Pload_media
            elif ti < 650:
                load[i] = P.Pload_alta
            elif ti < 850:
                load[i] = 700.0
            else:
                load[i] = P.Pload_base
    elif tipo == "limite_fonte":
        for i, ti in enumerate(t):
            load[i] = P.Pload_alta if ti >= 200 else P.Pload_media
    elif tipo == "perda_fonte":
        for i, ti in enumerate(t):
            load[i] = P.Pload_media
            grid[i] = 0 if 500 <= ti < 650 else 1
            pmax[i] = P.Psource_max_nominal * grid[i]
    elif tipo == "retorno_fonte":
        for i, ti in enumerate(t):
            load[i] = P.Pload_media
            grid[i] = 0 if 400 <= ti < 650 else 1
            pmax[i] = P.Psource_max_nominal * grid[i]
    else:
        raise ValueError(tipo)
    return load, pmax, grid


def planta(soc, pbess, uref, pload, pmax, grid):
    uref = min(max(uref, P.PBESS_min), P.PBESS_max)
    pb = P.ab * pbess + P.bb * uref
    pb = min(max(pb, P.PBESS_min), P.PBESS_max)
    if soc <= P.SOC_min and pb > 0:
        pb = 0.0
    if soc >= P.SOC_max and pb < 0:
        pb = 0.0
    psrc = (pload - pb) if grid == 1 else 0.0
    psrc = min(max(psrc, 0.0), pmax)
    pnao = max(0.0, pload - psrc - pb)
    if pb >= 0:
        d = (pb * P.Ts / 3600.0) / (P.Ebat * P.eta_d) * 100.0
    else:
        d = (pb * P.Ts / 3600.0) * P.eta_c / P.Ebat * 100.0
    soc2 = min(max(soc - d, P.SOC_min), P.SOC_max)
    return soc2, pb, psrc, pnao


def heur(pload, pmax, grid, soc):
    banda = 0.5
    pcmax = min(abs(P.PBESS_min), 150.0)
    if grid == 0:
        u = pload
    elif pload > pmax:
        u = pload - pmax
    else:
        folga = pmax - pload
        if soc < (P.SOC_ref - banda) and folga > 0:
            u = -min(folga, pcmax)
        else:
            u = 0.0
    if soc <= P.SOC_min and u > 0:
        u = 0.0
    if soc >= P.SOC_max and u < 0:
        u = 0.0
    return min(max(u, P.PBESS_min), P.PBESS_max)


def sim(tipo: str):
    load, pmax, grid = gera(tipo)
    n = len(load)
    soc, pbess, uref = P.SOC_ref, 0.0, 0.0
    pnao_max = 0.0
    for k in range(n - 1):
        u = heur(load[k], pmax[k], grid[k], soc)
        soc, pbess, _, pnao = planta(soc, pbess, u, load[k], pmax[k], grid[k])
        uref = u
        pnao_max = max(pnao_max, pnao)
    return pnao_max, soc


def main():
    kpi = OUT / "03_python_heuristico_kpi.csv"
    with kpi.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["cenario", "controle", "Pnao_max", "SOC_final"])
        for cen in ("carga_faixas", "limite_fonte", "perda_fonte", "retorno_fonte"):
            pnao, soc = sim(cen)
            w.writerow([cen, "heur", f"{pnao:.10f}", f"{soc:.10f}"])
            print(f"{cen:16s} heur Pnao_max={pnao:.4f} SOC={soc:.4f}")
    print("escrito", kpi)


if __name__ == "__main__":
    main()
