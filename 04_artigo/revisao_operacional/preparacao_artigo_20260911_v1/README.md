# Preparação técnica para o artigo — versão 11/09/2026

Este pacote organiza a formulação efetivamente executada, o diagnóstico numérico e os resultados rastreáveis. Não modifica o manuscrito, PDFs nem carta de resposta. A eventual adoção da reescala do solver não está embutida nas tabelas principais.

## Ordem de leitura

1. `FORMULACAO_QP.md`: convenções, preditores, custo, restrições, lógica de evento, formulação por cenários e métricas.
2. `DIAGNOSTICO_NUMERICO.md`: evidências, limitações, critérios e decisões sobre solver, SOC e tempos.
3. `RESULTADOS_E_ARGUMENTOS.md`: resultados que sustentam cada argumento e limites de interpretação.
4. `VALIDACAO_NUMERICA_PASSOS.md`: procedimento operacional antes de adotar mudanças numéricas.
5. `tabelas/`: CSVs e fragmentos LaTeX gerados das evidências consolidadas. `manifesto_fontes.json` identifica seus arquivos de origem e hashes.

## Base autoritativa para resultados

`05_resultados/revisao_operacional/consolidacao_corrigida_20260911_v1/`: 1.489 casos não afetados + 266 casos reexecutados após a correção do evento adiantado = 1.755 casos. A ablação isolada tem 21 casos separados. Ver `proveniencia.csv` para resolver cada job ao MAT e hash de origem. Não somar repetições de condições como novas realizações independentes; o Monte Carlo tem 200 realizações pareadas.

Experimentos de escala em `solver_escala_20260910_194722_777` (tentativa não aprovada) e `solver_escala_20260910_194805_009` (16 replays e quatro simulações) são diagnósticos auxiliares, não a versão principal do controlador.

## Situação da bancada

Em 11/09/2026 o autor informou que já está com a DE2-115 e pretende estruturar os testes na semana seguinte. Disponibilidade física da placa não equivale a teste de comunicação, firmware ou HIL aprovado. Retomar pelo guia `../HANDOFF_DE2115.md` e conferir versões, compiladores, cabos e porta no início da sessão. Nenhuma ação na placa foi executada nesta preparação. A escala do solver MATLAB não se transfere automaticamente aos parâmetros do ADMM embarcado.

## Decisões antes de redigir

- Tratar o ganho como redução de transientes e robustez sob hipóteses explícitas; não prometer continuidade integral com potência insuficiente.
- Apresentar o custo de reserva junto dos picos do estocástico.
- A desigualdade de evento tem contribuição marginal pequena nos casos testados; não apresentá-la como indispensável.
- Resolver a estratégia numérica antes de escolher a versão final do controlador para artigo e laboratório.
- Confirmar evidência física antes de qualquer afirmação de execução na DE2-115.
