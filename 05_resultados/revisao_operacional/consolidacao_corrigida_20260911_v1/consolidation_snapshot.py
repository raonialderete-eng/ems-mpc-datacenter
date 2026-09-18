"""Consolidate provenance-selected results. Never modifies historical evidence."""
from pathlib import Path
import argparse, csv, hashlib, json, collections, shutil
import numpy as np
from scipy.io import loadmat
from scipy.stats import beta

ROOT=Path(__file__).resolve().parents[2]
R=ROOT/'05_resultados/revisao_operacional'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def serial(x):
    if isinstance(x,np.ndarray):return x.tolist()
    if isinstance(x,np.generic):return x.item()
    raise TypeError(type(x).__name__)
def writecsv(p,rows):
    if not rows:return
    keys=list(dict.fromkeys(k for r in rows for k in r))
    with p.open('w',newline='',encoding='utf-8-sig') as f:
        w=csv.DictWriter(f,keys);w.writeheader();w.writerows(rows)
def js(p,x):p.write_text(json.dumps(x,default=serial,indent=2),encoding='utf-8')

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);a=ap.parse_args()
    dest=Path(a.output);dest.mkdir(parents=True,exist_ok=False)
    corrected=R/'evento_adiantado_corrigido_v1';base=R/'campanha_v1'
    assert json.loads((corrected/'status.json').read_text())['execution_complete']
    manifest=loadmat(corrected/'manifest.mat',simplify_cells=True)
    ids=[j['id'] for j in manifest['jobs']]
    assert len(ids)==266 and len(set(ids))==266
    assert {p.stem for p in corrected.glob('j*.mat')}==set(ids)
    for c in manifest['code']:assert sha(corrected/'src'/c['name'])==c['sha256']
    for ident,h in zip(ids,manifest['hashes']):assert sha(base/(ident+'.mat'))==h
    registered=json.loads((ROOT/'04_artigo/revisao_operacional/jobs.json').read_text())
    assert {j['id'] for j in registered}=={p.stem for p in base.glob('j*.mat')}
    rows=[];provenance=[];fallback=[];diagnostics={};pairs={};events=[]
    for i,j in enumerate(registered,1):
        ident=j['id'];fn=(corrected if ident in ids else base)/(ident+'.mat')
        data=loadmat(fn,simplify_cells=True);o=data['out'];job=data['job'];m=o['metrics'];p=o['param']
        assert job['id']==ident and job['ctrl']==j['ctrl'] and job['scenario']==j['scenario']
        L=np.asarray(o['case']['L']);M=np.asarray(o['case']['M']);G=np.asarray(o['case']['G'])
        pn=np.asarray(o['Pnao']);pb=np.asarray(o['PBESS'])[1:];soc=np.asarray(o['SOC'])
        assert np.all(np.isfinite(pn)) and np.all(np.isfinite(soc))
        assert len(pn)==len(L)-1 and np.max(np.abs(pn-np.maximum(0,L[:-1]-o['Psource']-pb)))<1e-8
        assert abs(pn.max()-m['P_raw_kW'])<1e-8 and abs(pn.sum()*p['Ts']/3600-m['E_raw_kWh'])<1e-8
        assert min(soc)>=p['SOC_min']-1e-8 and max(soc)<=p['SOC_max']+1e-8
        if ident in ids:
            old=loadmat(base/fn.name,simplify_cells=True)['out']
            for key in o['case']:assert np.array_equal(o['case'][key],old['case'][key])
            assert json.dumps(o['param'],default=serial,sort_keys=True)==json.dumps(old['param'],default=serial,sort_keys=True)
        row={k:v for k,v in job.items() if k!='params'}
        row['params_json']=json.dumps(job.get('params',{}),default=serial,sort_keys=True)
        row.update({k:v for k,v in m.items() if np.size(v)==1})
        row['evidence']=str(fn.relative_to(ROOT));row['campaign']=fn.parent.name;rows.append(row)
        provenance.append(dict(id=ident,source=row['evidence'],sha256=sha(fn),supersedes=str((base/fn.name).relative_to(ROOT)) if ident in ids else ''))
        if job['group']=='montecarlo':
            h=hashlib.sha256(np.concatenate([L,M,G]).tobytes()).hexdigest()
            pairs.setdefault(int(job['trial']),set()).add(h)
        ctrl=job['ctrl'];agg=diagnostics.setdefault(ctrl,dict(steps=0,fallback=0,flags=collections.Counter(),accepted_eq_max=0.,accepted_ineq_max=0.,accepted_soc_error_max=0.,overruns=[],soc_clipping_steps=0))
        ds=np.atleast_1d(o['diagnostics']);agg['steps']+=len(ds)
        rawsoc=soc[:-1]-np.where(pb>=0,pb/p['eta_descarga'],pb*p['eta_carga'])*p['Ts']/3600/p['Ebat']*100
        agg['soc_clipping_steps']+=int(np.sum((rawsoc<p['SOC_min']-1e-8)|(rawsoc>p['SOC_max']+1e-8)))
        for k,d in enumerate(ds):
            if d['usou_fallback']:
                agg['fallback']+=1;agg['flags'][str(d['exitflag'])]+=1
                fallback.append(dict(id=ident,ctrl=ctrl,step_0based=k,time_s=k*p['Ts'],exitflag=d['exitflag'],cause=d['fallback_causa'],command=o['u'][k],P_raw=pn[k],eq_residual=d['eq_residual'],source=row['evidence']))
            else:
                for key,src in [('accepted_eq_max','eq_residual'),('accepted_ineq_max','ineq_residual'),('accepted_soc_error_max','soc_error_pp')]:
                    if np.isfinite(d[src]):agg[key]=max(agg[key],float(d[src]))
            if o['cycle_s'][k]>p['Ts']:agg['overruns'].append(dict(id=ident,step_0based=k,seconds=float(o['cycle_s'][k])))
        for st,rec in zip(np.atleast_1d(m['recovery_event_starts_s']),np.atleast_1d(m['recovery_s'])):
            events.append(dict(id=ident,event_start_s=st,recovery_s=rec,source=row['evidence']))
        if i%350==0:print('AUDITED',i,flush=True)
    assert len(pairs)==200 and all(len(v)==1 for v in pairs.values())
    writecsv(dest/'resultados_consolidados.csv',rows);writecsv(dest/'proveniencia.csv',provenance)
    writecsv(dest/'fallback_eventos.csv',fallback);writecsv(dest/'recuperacao_eventos.csv',events)
    for group in sorted(set(r['group'] for r in rows)):
        writecsv(dest/('grupo_'+group+'.csv'),[r for r in rows if r['group']==group])
    pivot=[]
    for scenario in dict.fromkeys(r['scenario'] for r in rows if r['group']=='principal'):
        p={'scenario':scenario}
        for r in rows:
            if r['group']=='principal' and r['scenario']==scenario:p[r['ctrl']]=r['P_raw_kW']
        pivot.append(p)
    writecsv(dest/'tabela_P_unserved.csv',pivot)
    mc=[r for r in rows if r['group']=='montecarlo'];stats=[];differences=[]
    for ctrl in sorted(set(r['ctrl'] for r in mc)):
        sub={r['trial']:r for r in mc if r['ctrl']==ctrl};assert len(sub)==200
        v=np.array([r['P_raw_kW'] for r in sub.values()])
        stats.append(dict(ctrl=ctrl,n=200,mean=v.mean(),median=np.median(v),p95=np.quantile(v,.95),p99=np.quantile(v,.99),max=v.max(),mean_ENS=np.mean([r['E_raw_kWh'] for r in sub.values()]),mean_SOC_final=np.mean([r['SOC_final'] for r in sub.values()]),mean_throughput=np.mean([r['throughput_kWh'] for r in sub.values()]),mean_fallback_pct=np.mean([r['fallback_pct'] for r in sub.values()])))
        for ref in ['heuristico','mpc_qp_v5']:
            if ref==ctrl:continue
            refs={r['trial']:r for r in mc if r['ctrl']==ref}
            for metric,tol in [('P_raw_kW',.001),('E_raw_kWh',1e-6),('SOC_final',1e-6),('throughput_kWh',1e-6)]:
                d=np.array([sub[t][metric]-refs[t][metric] for t in sorted(sub)]);n=len(d);higher=int(sum(d>tol));lower=int(sum(d<-tol))
                rng=np.random.default_rng(20260911);boot=rng.choice(d,(2000,n),replace=True).mean(axis=1)
                differences.append(dict(ctrl=ctrl,reference=ref,metric=metric,n=n,tolerance=tol,mean_difference=d.mean(),median_difference=np.median(d),ci95_mean_low=np.quantile(boot,.025),ci95_mean_high=np.quantile(boot,.975),higher=higher,lower=lower,ties=n-higher-lower,higher_frequency=higher/n,higher_binomial_ci95_low=0 if higher==0 else beta.ppf(.025,higher,n-higher+1),higher_binomial_ci95_high=1 if higher==n else beta.ppf(.975,higher+1,n-higher)))
    writecsv(dest/'montecarlo_resumo.csv',stats);writecsv(dest/'montecarlo_diferencas_pareadas.csv',differences)
    abl=R/'ablacao_evento_campaign_20260910_165321_217'
    assert json.loads((abl/'status.json').read_text())['execution_complete']
    with (abl/'comparison.csv').open(encoding='utf-8-sig') as f:ab=list(csv.DictReader(f))
    assert len(ab)==21
    for row in ab:
        fn=abl/(row['scenario']+'_'+row['variant']+'.mat');o=loadmat(fn,simplify_cells=True)['out']
        assert abs(float(row['P_raw_kW'])-np.max(o['Pnao']))<1e-7
        row['evidence']=str(fn.relative_to(ROOT));row['sha256']=sha(fn)
    writecsv(dest/'ablacao_isolada.csv',ab)
    js(dest/'auditoria.json',dict(cases=1755,corrected_replacements=266,unchanged_cases=1489,ablation_cases=21,paired_MC_trials=200,metrics_recalculated=True,corrected_physical_inputs_and_params_identical=True,diagnostics=diagnostics))
    js(dest/'status.json',dict(consolidation_complete=True,scientific_scope='Traceable composition of 1489 original + 266 corrected cases; ablation separate. Solver-scale experiments excluded from rankings.',solver_and_hardware_validation='not implied by consolidation'))
    shutil.copy2(__file__,dest/'consolidation_snapshot.py')
    print('COMPLETE',str(dest),flush=True)
if __name__=='__main__':main()
