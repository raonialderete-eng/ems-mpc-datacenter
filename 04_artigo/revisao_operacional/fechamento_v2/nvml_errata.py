"""NVML metadata errata: raw_min_W/raw_max_W on GPU profiles are already in kW.
Does not modify dataset_v1/manifest.json."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[3]
MAN = ROOT / "05_resultados/revisao_operacional/dataset_v1/manifest.json"
OUT = ROOT / "05_resultados/revisao_operacional/fechamento_ensaios_v1/nvml_unidade_errata.json"


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    man = json.loads(MAN.read_text(encoding="utf8"))
    rows = []
    for p in man["profiles"]:
        if p.get("source_type") != "measured_gpu_power":
            continue
        rows.append({
            "id": p["id"],
            "field_as_stored": "raw_min_W / raw_max_W",
            "stored_min": p["raw_min_W"],
            "stored_max": p["raw_max_W"],
            "correct_unit": "kW",
            "incorrect_label": "W",
            "note": "preparar_dataset.py converted GPU watts to kW before aggregation, then wrote kW into *_W fields.",
        })
    OUT.write_text(json.dumps({"n": len(rows), "profiles": rows}, indent=2), encoding="utf8")
    print({"n": len(rows), "out": str(OUT)})


if __name__ == "__main__":
    main()
