function [u,info]=controle_mpc_qp_estocastico_3cen(SOC,PB,u0,pg0,L,M,G,p)
[u,info]=controle_mpc_auditado(SOC,PB,u0,pg0,L,M,G,p,true);
end
