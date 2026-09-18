"""Pre-register cases and paired trials before examining results."""
from pathlib import Path
import json,numpy as np
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'04_artigo/revisao_operacional/jobs.json'
CTRL=['heuristico','heuristico_foresight','miope_qp','mpc_qp_v5','mpc_qp_estocastico_3cen']
def main():
    assert not OUT.exists(), 'Job registration already exists'
    jobs=[]
    def add(group,scenario,ctrls=CTRL,params=None,**kw):
        for ctrl in ctrls:
            jobs.append(dict(id=f'j{len(jobs)+1:05d}',group=group,scenario=scenario,ctrl=ctrl,params=params or {},**kw))
    core=['carga_faixas','limite_fonte','perda_fonte','retorno_fonte','multi_burst','diploee_facility_stress','nvml_llama2_stress']
    for c in core: add('principal',c)
    for c in core:
        for du in [120,200,400]:
            add('fairness',c,params=dict(dPBESS_ref_max=du,dPBESS_ref_max_evento=du,common_slew=True),level=du)
        for label,params in [('load_only',dict(mpc_foresight_grid=False)),('no_preview',dict(mpc_foresight_grid=False,mpc_foresight_load=False)),('horizon1',dict(Np_mpc=1,Nc_mpc=1)),('no_event',dict(disable_event_constraint=True))]:
            add('ablacao',c,['mpc_qp_v5'],params=params,variant=label)
    for field in ['slack_load','slack_event','slack_source','slack_recharge','delta_u']:
        value=dict(slack_load=1e9,slack_event=1e9,slack_source=1e8,slack_recharge=1e6,delta_u=50)[field]
        for fac in [.1,1,10]:
            for c in ['perda_fonte','carga_faixas']:
                add('pesos',c,['mpc_qp_v5'],params={f'w_mpc_{field}':value*fac},weight=field,factor=fac)
    for sh in range(-20,21): add('timing','perda_fonte',forecast_shift=sh)
    for sh in [-10,0,10]: add('gate','perda_fonte',['mpc_qp_v5'],params=dict(event_arm_horizon=8),forecast_shift=sh)
    for fac in [.8,.9,1,1.1,1.2]: add('magnitude','perda_fonte',forecast_load_factor=fac)
    for mode in ['false_alarm','missed_event']: add('alarm','perda_fonte',event_mode=mode)
    for delay in [1,5,10]: add('detection','perda_fonte',event_mode='detection_delay',delay=delay)
    for soc in [30,45,60]:
        for tau in [1,2,4]:
            for c in ['perda_fonte','multi_burst']:
                add('plant_sensitivity',c,params=dict(SOC_initial=soc,tau_b=tau))
    for prefix in ['diploee_facility','nvml_llama2']:
        for j in range(1,21): add('windows',f'{prefix}_window{j:02d}')
    rng=np.random.default_rng(20260910)
    for i in range(200):
        sh=int(np.rint(np.clip(rng.normal(0,6),-20,20))); fac=float(rng.uniform(.8,1.2))
        add('montecarlo','perda_fonte',trial=i+1,forecast_shift=sh,forecast_load_factor=fac)
    for c in core:
        add('probabilities',c,['mpc_qp_estocastico_3cen'],params=dict(scenario_prob=[.5,.25,.25]))
    for c in ['falha_critica']: add('long_outage',c,['heuristico','mpc_qp_v5'],params=dict(Tf=9600))
    OUT.write_text(json.dumps(jobs,indent=2),encoding='utf-8')
    print('Registered jobs:',len(jobs))
if __name__=='__main__': main()
