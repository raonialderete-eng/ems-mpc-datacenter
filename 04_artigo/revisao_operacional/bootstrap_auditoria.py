"""Freeze pre-existing evidence and derive the QP builder without editing history."""
from pathlib import Path
import hashlib, json, datetime

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / '04_artigo/revisao_operacional'
CODE = ROOT / '01_matlab_base/revisao_operacional'

def sha(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda:f.read(1024*1024), b''): h.update(b)
    return h.hexdigest()

def main():
    CODE.mkdir(parents=True, exist_ok=True)
    manifest=OUT/'inventario_original.json'
    if not manifest.exists():
        entries=[]
        for folder in ['01_matlab_base','04_artigo','05_resultados','06_suplementar','07_fpga','dataset']:
            for p in sorted((ROOT/folder).rglob('*')):
                if p.is_file() and 'revisao_operacional' not in p.parts:
                    entries.append(dict(path=p.relative_to(ROOT).as_posix(),size=p.stat().st_size,sha256=sha(p)))
        manifest.write_text(json.dumps(dict(created_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),files=entries),indent=2),encoding='utf-8')
    src=ROOT/'01_matlab_base/controle_mpc_qp_v5.m'
    target=CODE/'montar_qp_auditado.m'
    if target.exists():
        print('Manifest preserved; builder already exists.'); return
    raw=src.read_text(encoding='utf-8-sig')
    prefix=raw[:raw.index('%  16. Resolver QP')]
    prefix=prefix[:prefix.rfind('%% ================================================================')]
    prefix=prefix.replace('function [PBESS_ref, info_mpc] = controle_mpc_qp_v5(', 'function q = montar_qp_auditado(' ,1)
    prefix=prefix.replace("%   - warm-start com solução do passo anterior.",'%   - builder only; solver and diagnostics are separate.')
    prefix=prefix.replace('SOC_ref = param.SOC_ref;', "if isfield(param,'Pbase_audit'), Pbase = param.Pbase_audit; end\nSOC_ref = param.SOC_ref;")
    prefix=prefix.replace('% Limite de variação do comando', "if isfield(param,'disable_event_constraint') && param.disable_event_constraint\n    PBESS_min_event(:)=0;\nend\n\n% Limite de variação do comando")
    names='H f Aineq bineq Aeq beq lb ub Np Nc idx_du idx_pgrid idx_slack_load idx_slack_source idx_slack_recharge idx_slack_event u_livre u_mat PBESS_livre PBESS_mat SOC_livre SOC_mat Pgrid_mat PBESS_min_event Psource_ref Psource_min_recharge dUmax dUmin modo_evento Pbase Rbase Kstep L Pmax grid'.split()
    tail="\n% Export exact V5 algebra; fixed normalization and optional event ablation.\nH=sparse((H+H')/2)+speye(nvar)*1e-6;\nAineq=sparse(Aineq); Aeq=sparse(Aeq);\nq=struct();\n"+''.join(f'q.{n}={n};\n' for n in names)+'end\n'
    target.write_text(prefix+tail,encoding='utf-8')
    (OUT/'origem_builder.json').write_text(json.dumps(dict(source=src.relative_to(ROOT).as_posix(),source_sha256=sha(src),derived=target.relative_to(ROOT).as_posix(),note='V5 sections 0-15; fixed normalization override; event-constraint ablation. Original untouched.'),indent=2),encoding='utf-8')
    print('Inventory and derived builder created.')

if __name__=='__main__': main()
