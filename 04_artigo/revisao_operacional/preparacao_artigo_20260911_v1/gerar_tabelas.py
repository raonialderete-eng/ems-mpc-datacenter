"""Export traceable CSV and LaTeX fragments; refuse to overwrite outputs."""
from pathlib import Path
import csv,json,hashlib,shutil,re
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
BASE=ROOT/'05_resultados/revisao_operacional/consolidacao_corrigida_20260911_v1'
OUT=HERE/'tabelas'
def load(p):
    with p.open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def esc(x):return str(x).replace('_',r'\_').replace('%',r'\%').replace('&',r'\&')
def num(x):
    v=float(x)
    if v==0:return '0'
    if abs(v)<.001:
        m,e=f'{v:.3e}'.split('e');return '$'+m+r'\times10^{'+str(int(e))+'}$'
    return f'{v:.6f}'.rstrip('0').rstrip('.')
def table(name,caption,headers,rows):
    path=OUT/name;assert not path.exists()
    lines=[r'\begin{table*}[t]',r'\centering',r'\small',r'\caption{'+caption+'}',
        r'\begin{tabular}{l'+'r'*(len(headers)-1)+'}',r'\hline',' & '.join(headers)+r' \\',r'\hline']
    lines+=[' & '.join(row)+r' \\' for row in rows]
    lines += [r'\hline',r'\end{tabular}',r'\end{table*}']
    path.write_text('\n'.join(lines)+'\n',encoding='utf-8')
def main():
    OUT.mkdir(exist_ok=False)
    sources=[]
    for name in ['tabela_P_unserved.csv','montecarlo_resumo.csv','montecarlo_diferencas_pareadas.csv','ablacao_isolada.csv','auditoria.json','proveniencia.csv']:
        p=BASE/name;shutil.copy2(p,OUT/name);sources.append(p)
    aux=ROOT/'05_resultados/revisao_operacional/solver_escala_20260910_194805_009'
    for name in ['closed_loop.csv','replay.csv','metadata.json']:
        p=aux/name;shutil.copy2(p,OUT/('solver_escala_'+name));sources.append(p)
    sources.append(ROOT/'05_resultados/revisao_operacional/solver_escala_20260910_194722_777/status.json')
    sources += [ROOT/'01_matlab_base'/n for n in ['parametros.m','planta_bess.m',
        'revisao_operacional/montar_qp_auditado.m','revisao_operacional/controle_mpc_auditado.m',
        'revisao_operacional/simular_ems_auditado.m','revisao_operacional/metricas_auditadas.m',
        'experimentos/solver_escala/avaliar_escala_solver.m']]
    ctrl=['heuristico','heuristico_foresight','miope_qp','mpc_qp_v5','mpc_qp_estocastico_3cen']
    labels=['Heuristic','Heuristic + forecast','Myopic QP','Deterministic MPC','Scenario MPC']
    scenarios={'carga_faixas':'Load bands','limite_fonte':'Source limit','perda_fonte':'Source loss',
        'retorno_fonte':'Source return','multi_burst':'Multiple bursts','diploee_facility_stress':'DIPLOEE stress','nvml_llama2_stress':'NVML stress'}
    rows=load(BASE/'tabela_P_unserved.csv')
    table('01_picos_principais.tex','Raw peak unserved power (kW), corrected event construction. Small residuals are retained.',
        ['Scenario','Heur.','Heur. + F','Myopic','MPC','Scenario MPC'],[[scenarios[r['scenario']]]+[num(r[c]) for c in ctrl] for r in rows])
    mc={r['ctrl']:r for r in load(BASE/'montecarlo_resumo.csv')}
    table('02_montecarlo_picos.tex','Peak unserved power (kW) over 200 paired forecast-error realizations.',
        ['Controller','Mean','Median','95th percentile','Maximum'],[[labels[i]]+[num(mc[c][k]) for k in ['mean','median','p95','max']] for i,c in enumerate(ctrl)])
    table('03_montecarlo_reserva.tex','Mean battery utilization and unserved energy over the same 200 realizations. SOC is in percent.',
        ['Controller','Unserved energy (kWh)',r'Final SOC (\%)','Throughput (kWh)',r'Fallback (\%)'],
        [[labels[i]]+[num(mc[c][k]) for k in ['mean_ENS','mean_SOC_final','mean_throughput','mean_fallback_pct']] for i,c in enumerate(ctrl)])
    ab=load(BASE/'ablacao_isolada.csv');abrows=[]
    for s in scenarios:
        sub={r['variant']:r for r in ab if r['scenario']==s}
        abrows.append([scenarios[s]]+[num(sub[v]['P_raw_kW']) for v in ['complete','inequality_only','legacy_package_off']])
    table('04_ablacao_isolada.tex','Raw peak unserved power (kW). Inequality-only ablation preserves references, costs, limits and fallback.',
        ['Scenario','Complete MPC','Inequality removed','Legacy coupled ablation'],abrows)
    sr=load(aux/'closed_loop.csv')
    table('05_escala_solver.tex','Auxiliary source-loss experiment, excluded from the main rankings. Scaled objective uses a factor of 0.001.',
        ['Controller / scaled','Peak (kW)',r'Final SOC (\%)','Throughput (kWh)','Fallback count'],
        [[labels[ctrl.index(r['ctrl'])]+' / '+r['scaled']]+[num(r[k]) for k in ['P_raw_kW','SOC_final','throughput_kWh','fallback_count']] for r in sr])
    formula=HERE/'FORMULACAO_QP.md';blocks=re.findall(r'\$\$(.*?)\$\$',formula.read_text(encoding='utf-8'),re.S)
    assert len(blocks)>=10
    (OUT/'equacoes_qp.tex').write_text('% Draft fragments: requires amsmath, amssymb and UTF-8 support.\n% Read FORMULACAO_QP.md for definitions and qualifications.\n'+
        '\n\n'.join(r'\begin{equation}'+'\n'+b.strip()+'\n'+r'\end{equation}' for b in blocks)+'\n',encoding='utf-8')
    sources.append(formula)
    manifest=dict(scope='Preparation only; canonical manuscript untouched. Solver-scale results remain auxiliary.',
        source_files=[dict(path=str(p.relative_to(ROOT)),sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in sources],
        outputs=[dict(path=str(p.relative_to(HERE)),sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in OUT.iterdir() if p.is_file()],
        latex_compilation='not executed; fragments require integration and layout verification',equation_blocks=len(blocks))
    (HERE/'manifesto_fontes.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    for p in OUT.glob('*.tex'):
        text=p.read_text(encoding='utf-8');assert text.count('{')==text.count('}'),p
    print(json.dumps(dict(tables=5,equations=len(blocks),csv_evidence_files=len(list(OUT.glob('*.csv'))),output=str(OUT))))
if __name__=='__main__':main()
