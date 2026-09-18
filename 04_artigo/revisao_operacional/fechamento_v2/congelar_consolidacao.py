"""Freeze hashes of the 11/09 consolidation. Read-only."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "05_resultados/revisao_operacional/consolidacao_corrigida_20260911_v1"
OUT = ROOT / "04_artigo/revisao_operacional/fechamento_v2/congelamento_consolidacao_20260911.json"


def sha(p: Path) -> str:
    h = hashlib.sha256()
    h.update(p.read_bytes())
    return h.hexdigest()


def main():
    files = sorted([p for p in SRC.iterdir() if p.is_file()])
    rec = [{"path": str(p.relative_to(ROOT)).replace("\\", "/"), "sha256": sha(p), "bytes": p.stat().st_size}
           for p in files]
    payload = {"role": "official_until_solver_gate", "n_files": len(rec), "files": rec}
    OUT.write_text(json.dumps(payload, indent=2), encoding="utf8")
    print({"n": len(rec), "out": str(OUT)})


if __name__ == "__main__":
    main()
