from pathlib import Path
import json,hashlib,argparse,shutil
ROOT=Path(__file__).resolve().parents[2]
def sha(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda:f.read(1048576),b''):h.update(b)
    return h.hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);ap.add_argument('--snapshot',action='store_true');a=ap.parse_args()
    dst=Path(a.output);dst.mkdir(parents=True,exist_ok=False)
    inv=json.loads((ROOT/'04_artigo/revisao_operacional/inventario_original.json').read_text())
    changed=[]
    for r in inv['files']:
        p=ROOT/r['path']
        if not p.is_file() or sha(p)!=r['sha256']:changed.append(r['path'])
    ds=ROOT/'05_resultados/revisao_operacional/dataset_v1'; m=json.loads((ds/'manifest.json').read_text())
    for r in m['inputs']:
        assert sha(ROOT/r['path'])==r['sha256'],'Dataset input hash changed'
    from scipy.io import loadmat
    import numpy as np
    for r in m['profiles']:
        p=ds/r['csv'];assert sha(p)==r['sha256'],'CSV changed'
        mat=loadmat(p.with_suffix('.mat'),simplify_cells=True)
        csv=np.loadtxt(p,delimiter=',',skiprows=1)
        assert np.array_equal(mat['L'],csv[:,1]),'MAT does not match registered CSV'
        assert np.all(mat['M']==800) and np.all(mat['G']==1)
    if a.snapshot:
        for folder in ['01_matlab_base/revisao_operacional','07_fpga/revisao_operacional','04_artigo/revisao_operacional']:
            shutil.copytree(ROOT/folder,dst/folder)
        # The baseline dependencies used by the new simulator are also frozen.
        base=dst/'01_matlab_base';base.mkdir(exist_ok=True,parents=True)
        for p in (ROOT/'01_matlab_base').glob('*.m'):shutil.copy2(p,base/p.name)
    result=dict(original_files_checked=len(inv['files']),changed_originals=changed,dataset_profiles_verified=len(m['profiles']),snapshot=bool(a.snapshot))
    (dst/'integridade.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(result));assert not changed,'Historical files changed'
if __name__=='__main__':main()
