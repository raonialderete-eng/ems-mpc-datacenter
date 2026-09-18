"""Offline-only official dataset preprocessing. New immutable output directory."""
from pathlib import Path
import csv, json, hashlib, argparse
import numpy as np
from scipy.io import savemat

ROOT=Path(__file__).resolve().parents[2]
def digest(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda:f.read(1048576),b''): h.update(b)
    return h.hexdigest()

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--output',required=True); a=ap.parse_args()
    out=Path(a.output).resolve(); out.mkdir(parents=True,exist_ok=False)
    ds=ROOT/'dataset'; rng=np.random.default_rng(20260909)
    facility=ds/'03_whole-facility_profiles/inference/simulated_data/inference_1MW_283nodes_40u_power.csv'
    assert facility.is_file(),facility
    with facility.open() as f:
        rd=csv.reader(f); next(rd); fac=np.array([float(r[1]) for r in rd])
    logs=sorted((ds/'00_raw_datasets/training_llama2_70b_lora/16node').glob('nvml_wattameter_emissions_parsed_slurmid_10742842_*.log'))
    assert len(logs)==16, f'Expected 16 node logs, got {len(logs)}'
    streams=[]
    for path in logs:
        ts=[]; power=[]
        for row in path.read_text().splitlines():
            if not row.strip() or row.lstrip().startswith('#'): continue
            cols=row.split()
            ts.append(np.datetime64(cols[0].replace('_','T'),'us').astype('int64')/1e6)
            power.append(sum(map(float,cols[2:6]))*1e-3)
        ts=np.array(ts); power=np.array(power)
        assert np.all(np.isfinite(power)) and np.all(np.diff(ts)>=0)
        unique,idx=np.unique(ts,return_index=True); streams.append((unique,power[idx]))
    start=max(t[0] for t,p in streams); end=min(t[-1] for t,p in streams)
    grid=np.arange(int(np.floor(end-start))+1)+start
    assert len(grid)>=1201
    nvml=sum(np.interp(grid,t,p) for t,p in streams)
    records=[]; inputs=[facility,*logs]
    for name,raw,width,step in [('diploee_facility',fac,21,60),('nvml_llama2',nvml,1201,1)]:
        assert len(raw)>=width and np.all(np.isfinite(raw))
        # Chunk-free rolling extrema; independent from all controller outcomes.
        from scipy.ndimage import maximum_filter1d, minimum_filter1d
        # trailing alignment via direct strided windows (views, no large copies)
        windows=np.lib.stride_tricks.sliding_window_view(raw,width)
        ranges=windows.max(axis=1)-windows.min(axis=1)
        stress=int(np.argmax(ranges)); candidates=np.arange(len(ranges)); candidates=candidates[candidates!=stress]
        picks=[stress,*rng.choice(candidates,size=20,replace=False).tolist()]
        for j,i in enumerate(picks):
            segment=raw[i:i+width]; tt=np.arange(1201,dtype=float)
            interp=np.interp(tt,np.arange(width)*step,segment)
            span=float(interp.max()-interp.min())
            norm=(interp-interp.min())/span if span>1e-9 else np.full_like(interp,.5)
            power=600+350*norm; ident=f'{name}_{"stress" if j==0 else f"window{j:02d}"}'
            fn=out/f'{ident}.csv'
            np.savetxt(fn,np.c_[tt,power,norm],delimiter=',',header='t_s,P_kW,power_normalized',comments='')
            savemat(out/f'{ident}.mat',dict(L=power,M=np.full_like(power,800),G=np.ones_like(power)))
            records.append(dict(id=ident,source_type='simulated_facility' if name.startswith('diploee') else 'measured_gpu_power',window_index_zero_based=i,source_step_s=step,raw_min_W=float(segment.min()),raw_max_W=float(segment.max()),transform='linear interpolation to 1s; per-window affine [600,950] kW',selection='maximum amplitude' if j==0 else 'seeded random without replacement; overlap possible',csv=fn.name,sha256=digest(fn)))
    (out/'manifest.json').write_text(json.dumps(dict(seed=20260909,inputs=[dict(path=str(p.relative_to(ROOT)),sha256=digest(p)) for p in inputs],profiles=records),indent=2),encoding='utf-8')
    print(json.dumps(dict(output=str(out),profiles=len(records),nvml_seconds=len(nvml))))

if __name__=='__main__': main()
