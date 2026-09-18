"""Select stratified QP replay cases from fallback_eventos.csv before seeing new KPIs."""
from pathlib import Path
import csv
import json
from collections import defaultdict

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "05_resultados/revisao_operacional/consolidacao_corrigida_20260911_v1/fallback_eventos.csv"
OUT = Path(__file__).resolve().parent / "replay_index.json"


def main():
    rows = list(csv.DictReader(SRC.open(encoding="utf8")))
    buckets = defaultdict(list)
    for r in rows:
        if r["ctrl"] != "mpc_qp_v5":
            continue
        flag = r["exitflag"]
        mat = ROOT / r["source"]
        if not mat.is_file():
            continue
        buckets[flag].append({"mat": str(mat).replace("\\", "/"), "step": int(r["step_0based"]) + 1,
                              "stratum": f"flag_{flag}"})
    rng_i = 0
    chosen = []
    for flag, items in buckets.items():
        n = min(6, len(items))
        step = max(1, len(items) // n)
        pick = items[::step][:n]
        for p in pick:
            p["stratum"] = f"flag_{flag}"
        chosen.extend(pick)
        rng_i += 1
    # Controls: first QP of principal loss (no fallback expected at start)
    ctrl = ROOT / "05_resultados/revisao_operacional/campanha_v1/j00014.mat"
    if ctrl.is_file():
        chosen.append({"mat": str(ctrl).replace("\\", "/"), "step": 1, "stratum": "control_k1"})
        chosen.append({"mat": str(ctrl).replace("\\", "/"), "step": 200, "stratum": "control_mid"})
    OUT.write_text(json.dumps(chosen, indent=2), encoding="utf8")
    print({"n": len(chosen), "flags": {k: len(v) for k, v in buckets.items()}})


if __name__ == "__main__":
    main()
