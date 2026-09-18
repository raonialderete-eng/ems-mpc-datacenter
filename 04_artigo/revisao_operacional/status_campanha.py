from pathlib import Path
from collections import Counter,defaultdict
import json,argparse
ROOT=Path(__file__).resolve().parents[2]
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--run',default='campanha_v1');a=ap.parse_args()
    jobs=json.loads((ROOT/'04_artigo/revisao_operacional/jobs.json').read_text())
    folder=ROOT/'05_resultados/revisao_operacional'/a.run
    complete={p.stem for p in folder.glob('j*.mat')}; counts=Counter(j['group'] for j in jobs if j['id'] in complete); total=Counter(j['group'] for j in jobs)
    status=dict(run=a.run,completed=len(complete),registered=len(jobs),run_lock_present=(folder/'RUNNING.lock').exists(),groups={k:dict(completed=counts[k],registered=v) for k,v in total.items()},note='Lock presence alone does not prove a live process. Scientific validation and board execution are separate.')
    print(json.dumps(status,indent=2))
if __name__=='__main__':main()
