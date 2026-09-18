from pathlib import Path
import csv, json, hashlib
import numpy as np
from scipy.io import loadmat

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
BASE=ROOT/'05_resultados/revisao_operacional/consolidacao_corrigida_20260911_v1'
rows=list(csv.DictReader((BASE/'resultados_consolidados.csv').open(encoding='utf-8-sig')))
def val(r,k): return float(r[k])
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
report={'sources':{},'case_count':len(rows)}
report['sources']['consolidated_csv']=digest(BASE/'resultados_consolidados.csv')
report['sources']['review_pdf']=digest(ROOT/'04_artigo/IEEE_ACESS_PARECER.pdf')
report['groups']={g:sum(r['group']==g for r in rows) for g in sorted({r['group'] for r in rows})}
timing=[r for r in rows if r['group']=='timing']
report['timing']={}
for ctrl in ['mpc_qp_v5','mpc_qp_estocastico_3cen']:
    rr=[r for r in timing if r['ctrl']==ctrl]
    report['timing'][ctrl]={'min_peak':min(val(r,'P_raw_kW') for r in rr),
        'max_peak':max(val(r,'P_raw_kW') for r in rr),
        'shifts_worse_than_heuristic':[int(r['forecast_shift']) for r in rr if val(r,'P_raw_kW')>592.6122638850534+.001],
        'shifts_with_peak_within_1kW_of_350':[int(r['forecast_shift']) for r in rr if val(r,'P_raw_kW')<=351],
        'selected':[{k:r[k] for k in ['forecast_shift','P_raw_kW','SOC_final','fallback_pct']} for r in rr if int(r['forecast_shift']) in [-20,-10,0,10,20]]}
report['main_soc_diagnostics']=[]
report['main_peak_locations']=[]
for r in rows:
    if r['group']!='principal': continue
    path=ROOT/r['evidence']; d=loadmat(path,simplify_cells=True)
    o=d.get('out',d.get('o'))
    if o is None:
        candidates=[v for v in d.values() if isinstance(v,dict) and 'Pnao' in v]
        assert len(candidates)==1, (path,list(d));o=candidates[0]
    peak=int(np.argmax(o['Pnao']))
    report['main_peak_locations'].append(dict(id=r['id'],ctrl=r['ctrl'],scenario=r['scenario'],step_0based=peak,
        peak=float(o['Pnao'][peak]),load=float(o['case']['L'][peak]),limit=float(o['case']['M'][peak])))
    if r['ctrl'] not in ['mpc_qp_v5','mpc_qp_estocastico_3cen']:continue
    ds=np.asarray(o['diagnostics'],dtype=object).ravel().tolist()
    accepted=[x for x in ds if not x['usou_fallback'] and x['exitflag']>0]
    report['main_soc_diagnostics'].append(dict(id=r['id'],ctrl=r['ctrl'],scenario=r['scenario'],
        accepted_steps=len(accepted),steps_with_sign_mismatch=sum(x['soc_sign_mismatch']>0 for x in accepted),
        summed_horizon_sign_mismatches=sum(x['soc_sign_mismatch'] for x in accepted),
        max_soc_error_pp=max(x['soc_error_pp'] for x in accepted),
        max_piecewise_soc_violation_pp=max(x['soc_pred_violation'] for x in accepted),
        source=str(path.relative_to(ROOT)),sha256=digest(path)))
report['plant_sensitivity']=[]
for r in rows:
    if r['group']=='plant_sensitivity':
        report['plant_sensitivity'].append({k:r[k] for k in ['id','scenario','ctrl','params_json','P_raw_kW','SOC_min','fallback_pct']})
report['long_outage']=[{k:r[k] for k in ['id','ctrl','SOC_min','SOC_final','E_raw_kWh','recovery_s','SOC_at_events','throughput_kWh']} for r in rows if r['group']=='long_outage']
report['numerical_summary']={}
for ctrl in ['mpc_qp_v5','mpc_qp_estocastico_3cen']:
    rr=[r for r in rows if r['ctrl']==ctrl]
    report['numerical_summary'][ctrl]={k:max(val(r,k) for r in rr if np.isfinite(val(r,k))) for k in ['soc_prediction_violation_pp','constraint_gram_cond','cycle_p99_s']}
path=HERE/'checagem_evidencias.json'
assert not path.exists()
path.write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k not in ['plant_sensitivity','main_peak_locations']},indent=2,ensure_ascii=False))
