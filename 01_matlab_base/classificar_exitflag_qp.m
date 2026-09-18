function causa = classificar_exitflag_qp(exitflag)
% CLASSIFICAR_EXITFLAG_QP
% Taxonomia de causas de falha/aviso do quadprog (MATLAB).

if isempty(exitflag) || ~isfinite(exitflag)
    causa = 'solucao_vazia_ou_nao_finita';
    return;
end

switch exitflag
    case 1
        causa = 'ok';
    case 0
        causa = 'limite_iteracoes';
    case -2
        causa = 'qp_inviavel';
    case -3
        causa = 'nao_limitado';
    case -6
        causa = 'nao_convexo';
    case -8
        causa = 'erro_numerico_step';
    otherwise
        if exitflag < 0
            causa = sprintf('erro_numerico_exitflag_%d', exitflag);
        else
            causa = sprintf('exitflag_%d', exitflag);
        end
end

end
