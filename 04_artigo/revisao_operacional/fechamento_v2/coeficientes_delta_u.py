import csv
from pathlib import Path
Pbase = 950.0
w = 50.0
OUT = Path(__file__).resolve().parents[3] / "05_resultados/revisao_operacional/fechamento_ensaios_v1/coeficientes_delta_u.csv"
OUT.parent.mkdir(parents=True, exist_ok=True)
rows = [
    {"controller": "miope", "term": "w_du*(u-u0)^2/Pbase^2", "w": w, "Pbase": Pbase,
     "coef_on_du2": w / (Pbase ** 2), "event_mode_scale": 1.0},
    {"controller": "mpc_qp_v5", "term": "w_mpc_delta_u*||DeltaU||^2 (no Pbase^2)", "w": w, "Pbase": Pbase,
     "coef_on_du2": w, "event_mode_scale": 0.1, "note": "event mode uses 5 in V5 when documented"},
]
ratio = w / (w / (Pbase ** 2))
with OUT.open("w", newline="", encoding="utf8") as f:
    wri = csv.DictWriter(f, fieldnames=["controller", "term", "w", "Pbase", "coef_on_du2", "event_mode_scale", "note"])
    wri.writeheader()
    wri.writerows(rows)
    wri.writerow({"controller": "ratio_mpc_over_miope_nominal", "term": "coef_mpc/coef_miope",
                  "w": w, "Pbase": Pbase, "coef_on_du2": ratio, "event_mode_scale": ratio / 10,
                  "note": "902500 nominal; 90250 if event uses w=5"})
print(OUT, "ratio", ratio)
