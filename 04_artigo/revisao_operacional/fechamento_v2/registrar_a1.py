from pathlib import Path
import json
HERE=Path(__file__).resolve().parent
ctrls=['mpc_qp_v5','mpc_qp_estocastico_3cen']
def write(name,jobs):
    path=HERE/name
    assert not path.exists()
    path.write_text(json.dumps(jobs,indent=2),encoding='utf8')
pilot=[];full=[]
for policy in ['legacy','persistence']:
    for ctrl in ctrls:
        pilot.append(dict(id=f'p{len(pilot)+1:04d}',group='A1_pilot',scenario='perda_fonte',ctrl=ctrl,pilot=True,
            params=dict(information_policy=policy,mpc_foresight_grid=False),reviewers=['R2.3','R2.4','R5.1']))
        for scenario,variant,extra in [('perda_fonte','announced',{}),('retorno_fonte','announced',{}),
                ('perda_fonte','load_only',{'mpc_foresight_grid':False}),
                ('perda_fonte','no_preview',{'mpc_foresight_grid':False,'mpc_foresight_load':False})]:
            full.append(dict(id=f'a1_{len(full)+1:04d}',group='A1',scenario=scenario,ctrl=ctrl,variant=variant,
                params=dict(information_policy=policy,**extra)))
        for delay in [1,5,10]:
            full.append(dict(id=f'a1_{len(full)+1:04d}',group='A1',scenario='perda_fonte',ctrl=ctrl,
                event_mode='detection_delay',delay=delay,params=dict(information_policy=policy)))
write('jobs_a1_pilot.json',pilot);write('jobs_a1.json',full)
print({'pilot':len(pilot),'full':len(full)})
