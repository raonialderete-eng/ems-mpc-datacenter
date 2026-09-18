"""Create isolated A/B implementation; never modify historical sources/results."""
from pathlib import Path
import hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
SRC=ROOT/'01_matlab_base/experimentos/fechamento_v2/src'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    assert not SRC.exists(),'Frozen source bundle already exists'
    originals=list((ROOT/'01_matlab_base').glob('*.m'))+list((ROOT/'01_matlab_base/revisao_operacional').glob('*.m'))
    refs=list((ROOT/'05_resultados/revisao_operacional/consolidacao_corrigida_20260911_v1').glob('*'))
    refs=[p for p in refs if p.is_file()]
    profiles=list((ROOT/'05_resultados/revisao_operacional/dataset_v1').glob('*'))
    profiles=[p for p in profiles if p.is_file()]
    protected=[ROOT/'04_artigo/IEEE_ACESS_PARECER.pdf',*list((ROOT/'04_artigo/ieee_access').glob('*.tex'))]
    files=originals+refs+profiles+protected
    manifest={'version':'v2','historical_files':[{'path':str(p.relative_to(ROOT)),'sha256':sha(p)} for p in files]}
    SRC.mkdir(parents=True)
    for p in originals:shutil.copy2(p,SRC/p.name)
    builder=(SRC/'montar_qp_auditado.m').read_text(encoding='utf-8-sig')
    (SRC/'montar_qp_historico_v2.m').write_text(builder.replace('function q = montar_qp_auditado(', 'function q = montar_qp_historico_v2(',1),encoding='utf8')
    # The authoritative information packet has already applied forecast policy.
    start=builder.index('if ~foresight_grid && Np >= 2')
    end=builder.index('%% ================================================================',start)
    builder=builder[:start]+"assert(isfield(param,'information_prepared') && param.information_prepared,'Use preparar_informacao_v2 before building QP');\n\n"+builder[end:]
    event_start=builder.index('PBESS_min_event = zeros(Np,1);')
    event_end=builder.index('% Limite de variação do comando',event_start)
    ref_start=builder.index("if isfield(param, 'P_recarga_mpc_max')")
    ref_end=builder.index('%% ================================================================',ref_start)
    event=builder[event_start:event_end]
    ref=builder[ref_start:ref_end]
    helper="""function [PBESS_min_event,modo_evento,Psource_ref,Psource_min_recharge,info_mpc]=referencias_evento_v2(L,Pmax,grid,SOC_atual,param)
% Exact extraction of historical event/recharge logic, no QP construction.
L=L(:);Pmax=Pmax(:);grid=grid(:);Np=numel(L);SOC_ref=param.SOC_ref;
Nprep=30;if isfield(param,'Nprep_evento_mpc'),Nprep=param.Nprep_evento_mpc;end
info_mpc=struct();
"""+event+ref+'\nend\n'
    (SRC/'referencias_evento_v2.m').write_text(helper,encoding='utf8')
    builder=builder[:ref_start]+'% References are produced by the shared event helper.\n\n'+builder[ref_end:]
    builder=builder[:event_start]+"[PBESS_min_event,modo_evento,Psource_ref,Psource_min_recharge,event_info]=referencias_evento_v2(L,Pmax,grid,SOC_atual,param);\n"+builder[event_end:]
    needle='q.Aineq=Aineq;'
    builder=builder.replace(needle,"""q.event_rows=size(Aineq,1)-n_event+(1:n_event);
if isfield(param,'ablate_event_inequality_only') && param.ablate_event_inequality_only
    assert(~(isfield(param,'disable_event_constraint') && param.disable_event_constraint));
    Aineq(q.event_rows,:)=[];bineq(q.event_rows)=[];
end
q.Aineq=Aineq;""")
    (SRC/'montar_qp_auditado.m').write_text(builder,encoding='utf8')
    (HERE/'congelamento_a0.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
    print(json.dumps({'frozen_files':len(files),'src':str(SRC)}))
if __name__=='__main__':main()
