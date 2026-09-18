"""Read-only MAT evidence -> versioned CSV/JSON/figures. No historical writes."""
from pathlib import Path
import argparse,csv,json,math
import numpy as np
from scipy.io import loadmat
from scipy.stats import beta

def serial(x):
    if isinstance(x,np.ndarray): return x.tolist()
    if isinstance(x,np.generic): return x.item()
    return x

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--run',required=True); ap.add_argument('--output',required=True); a=ap.parse_args()
    src=Path(a.run); dst=Path(a.output); dst.mkdir(parents=True,exist_ok=False)
    rows=[]; issues=[]; fallback=[]
    for fn in sorted(src.glob('j*.mat')):
        data=loadmat(fn,simplify_cells=True); o=data['out']; job=data['job']; m=o['metrics']
        r={k:serial(v) for k,v in job.items() if k!='params'}
        r['params_json']=json.dumps(job.get('params',{}),default=serial,sort_keys=True)
        r.update({k:serial(v) for k,v in m.items() if np.size(v)==1})
        r['wall_s']=float(o['wall_s']); r['evidence']=fn.name; rows.append(r)
        di=o['diagnostics']; di=[di] if isinstance(di,dict) else di
        for k,d in enumerate(di):
            if d['usou_fallback']:
                fallback.append(dict(job=job['id'],step=k,time_s=k*o['param']['Ts'],ctrl=job['ctrl'],exitflag=d['exitflag'],cause=d['fallback_causa'],u_kW=o['u'][k],P_unserved_kW=o['Pnao'][k],ineq_residual=d['ineq_residual'],eq_residual=d['eq_residual']))
        if float(m['SOC_min'])<20-1e-6 or float(m['SOC_max'])>90+1e-6: issues.append(dict(job=job['id'],issue='SOC physical bound violation'))
    def write(name,items):
        if not items:return
        keys=list(dict.fromkeys(k for r in items for k in r));
        with (dst/name).open('w',newline='',encoding='utf-8-sig') as f:
            w=csv.DictWriter(f,fieldnames=keys); w.writeheader(); w.writerows(items)
    write('resultados_completos.csv',rows); write('fallback_eventos.csv',fallback)
    for group in sorted(set(r['group'] for r in rows)):
        write('grupo_'+group+'.csv',[r for r in rows if r['group']==group])
    primary=[r for r in rows if r['group']=='principal']; write('comparacao_cinco_controladores.csv',primary)
    pivot=[]
    for scenario in dict.fromkeys(r['scenario'] for r in primary):
        row=dict(scenario=scenario)
        for r in primary:
            if r['scenario']==scenario:
                row[r['ctrl']+'_raw_kW']=r['P_raw_kW']; row[r['ctrl']+'_filtered_kW']=r['P_filtered_kW']
        pivot.append(row)
    write('tabela_P_unserved.csv',pivot)
    stats=[]; mc=[r for r in rows if r['group']=='montecarlo']; ref={r['trial']:r for r in mc if r['ctrl']=='heuristico'}
    for ctrl in sorted(set(r['ctrl'] for r in mc)):
        sub=[r for r in mc if r['ctrl']==ctrl and r['trial'] in ref]; n=len(sub)
        if not n:continue
        differences=np.array([r['P_raw_kW']-ref[r['trial']]['P_raw_kW'] for r in sub]); worse=int(sum(differences>1e-3))
        # Exact binomial interval; IID pertains to chosen forecast-error distribution only.
        low=0 if worse==0 else beta.ppf(.025,worse,n-worse+1)
        high=1 if worse==n else beta.ppf(.975,worse+1,n-worse)
        rng=np.random.default_rng(20260911)
        boots=np.mean(rng.choice(differences,(2000,n),replace=True),axis=1)
        stats.append(dict(ctrl=ctrl,n_paired=n,worse=worse,frequency=worse/n,ci95_low=low,ci95_high=high,mean_peak_difference_kW=float(differences.mean()),difference_ci95_low=float(np.quantile(boots,.025)),difference_ci95_high=float(np.quantile(boots,.975)),peak_p95=float(np.quantile([r['P_raw_kW'] for r in sub],.95))))
    write('montecarlo_pareado.csv',stats)
    (dst/'status.json').write_text(json.dumps(dict(completed=len(rows),groups={g:sum(r['group']==g for r in rows) for g in sorted(set(r['group'] for r in rows))},issues=issues,source=str(src.resolve())),indent=2),encoding='utf-8')
    if primary:
        import matplotlib; matplotlib.use('Agg')
        import matplotlib.pyplot as plt
        fig,ax=plt.subplots(figsize=(11,5)); ctrls=list(dict.fromkeys(r['ctrl'] for r in primary)); scenarios=list(dict.fromkeys(r['scenario'] for r in primary)); width=.15
        for j,ctrl in enumerate(ctrls):
            vals=[next((r['P_raw_kW'] for r in primary if r['scenario']==s and r['ctrl']==ctrl),np.nan) for s in scenarios]
            ax.bar(np.arange(len(scenarios))+j*width,vals,width,label=ctrl)
        ax.set_xticks(np.arange(len(scenarios))+width*2,scenarios,rotation=20,ha='right'); ax.set_ylabel('Peak unserved power, raw (kW)'); ax.legend(fontsize=7); fig.tight_layout(); fig.savefig(dst/'comparacao_picos.png',dpi=160); plt.close(fig)
    print(json.dumps(dict(completed=len(rows),output=str(dst))))
if __name__=='__main__':main()
