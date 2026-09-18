"""Post-process existing principal MATs for preparation energy and reversals."""
from pathlib import Path
import csv
import json

try:
    import numpy as np
    from scipy.io import loadmat
except ImportError:
    np = None
    loadmat = None

ROOT = Path(__file__).resolve().parents[3]
PROV = ROOT / "05_resultados/revisao_operacional/consolidacao_corrigida_20260911_v1/grupo_principal.csv"
OUT = ROOT / "05_resultados/revisao_operacional/fechamento_ensaios_v1/metricas_prep_reversao_principal.csv"


def metrics_from_mat(path: Path):
    d = loadmat(path, squeeze_me=True, struct_as_record=False)
    o = d["out"]
    u = np.atleast_1d(np.array(o.u, dtype=float)).ravel()
    G = np.atleast_1d(np.array(o.case.G, dtype=float)).ravel()
    L = np.atleast_1d(np.array(o.case.L, dtype=float)).ravel()
    M = np.atleast_1d(np.array(o.case.M, dtype=float)).ravel()
    n = min(len(u), len(G) - 1)
    u = u[:n]
    sg = np.sign(u)
    sg[sg == 0] = 1
    reversals = int(np.sum(np.diff(sg) != 0))
    active = (G[:n] == 0) | (L[:n] > M[:n])
    starts = np.where(np.diff(np.r_[False, active]) == 1)[0]
    prep = 0.0
    if len(starts):
        i1 = max(0, starts[0] - 1)
        i0 = max(0, starts[0] - 30)
        prep = float(np.sum(np.maximum(u[i0:i1 + 1], 0)) / 3600.0)
    return reversals, prep


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    if loadmat is None:
        OUT.write_text("id,ctrl,scenario,u_reversals,E_prep_kWh,note\n", encoding="utf8")
        print("scipy missing")
        return
    rows = list(csv.DictReader(PROV.open(encoding="utf8")))
    out_rows = []
    for r in rows:
        mat = ROOT / r.get("evidence", r.get("source", ""))
        if not mat.is_file():
            # try campanha path from id
            cand = ROOT / "05_resultados/revisao_operacional/campanha_v1" / f"{r['id']}.mat"
            if cand.is_file():
                mat = cand
            else:
                continue
        try:
            rev, prep = metrics_from_mat(mat)
            out_rows.append({**{k: r[k] for k in r if k in ("id", "ctrl", "scenario")},
                             "u_reversals": rev, "E_prep_kWh": prep})
        except Exception as exc:
            out_rows.append({"id": r.get("id"), "error": str(exc)})
    if out_rows:
        keys = sorted({k for row in out_rows for k in row})
        with OUT.open("w", newline="", encoding="utf8") as f:
            w = csv.DictWriter(f, fieldnames=keys)
            w.writeheader()
            w.writerows(out_rows)
    print({"n": len(out_rows), "out": str(OUT)})


if __name__ == "__main__":
    main()
