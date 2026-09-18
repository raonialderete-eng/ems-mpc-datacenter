# Procedimento para fechar a validação numérica

Este procedimento está estruturado para execução posterior. Não marca como executados testes ainda não realizados e não altera automaticamente a escala da versão principal.

## 1. Congelar a configuração antes dos ensaios

- Definir versão principal sem reescala e candidata com multiplicação conjunta de H e f por 0,001. Manter pesos relativos, restrições, planta e fallback.
- Registrar algoritmo, versão, tolerâncias, limites de iterações, precisão e inicialização de cada solver. O ensaio anterior com tolerância estrita falhou: não excluí-lo.
- Escolher tolerâncias por unidades físicas e resíduos relativos antes de ver novos resultados. A tolerância de primeira ação <0,1 kW pertence ao estudo existente; justificar seu uso futuro e reportar os valores efetivos.
- Usar diretório novo com hash de entradas, código e configurações; não retomar checkpoints incompatíveis.

## 2. Reproduzir o diagnóstico existente

No MATLAB, a partir da raiz do projeto:

```matlab
addpath('01_matlab_base/experimentos/solver_escala');
dest = avaliar_escala_solver();
```

O script existente cria saída própria, executa os 16 replays e, se aprovados, quatro malhas fechadas. Ele não muda os controladores de produção. Ler `status.json`, `replay.csv`, `closed_loop.csv` e os snapshots. A execução não deve coincidir com medições destinadas a sustentar prazos.

## 3. Ampliar a seleção sem escolher apenas casos favoráveis

Usar `consolidacao_corrigida_20260911_v1/fallback_eventos.csv` como índice. Estratificar por controlador, grupo, exitflag, SOC inicial, tau e posição do evento. Incluir: falhas -6, -2 e 0; amostras aprovadas como controles; maiores resíduos; transições de carga/descarga; aproximação dos limites SOC. O builder do míope é diferente e não deve ser enviado ao reconstrutor do MPC como se fosse o mesmo QP.

O script atual cobre 16 falhas -6; extensão para todos esses estratos e coleta completa de KKT ainda precisam ser implementadas. Preservar estados e entradas do passo original; não usar estado de uma nova trajetória para alegar replay do antigo.

## 4. Critérios por replay

1. Reconstrução reproduz o QP e identifica a origem por hash.
2. H e f escalados conjuntamente; A, E, limites e referências invariantes.
3. Avaliar simetria, Cholesky/autovalor quando necessário, resíduos físicos e relativos, multiplicadores, complementaridade e custo original.
4. Comparar primeira ação e sequência com referências de outro algoritmo e, quando possível, inicializações distintas.
5. Diferenciar código de saída, qualidade da solução candidata e ação efetivamente aplicada. Registrar recusas com o mesmo cuidado que aprovações.

## 5. Critérios em malha fechada

Depois dos replays, comparar ambas as versões em perda/retorno, bursts, perfis oficiais, SOC baixo, tau=1/2/4, erros de previsão, ausência de anúncio e falta prolongada. Preservar resultados em que a candidata perde energia, SOC ou outro indicador. Não escolher a versão apenas por reduzir fallback.

Se a escala for adotada para os números finais do artigo, reexecutar os casos afetados da versão determinística e estocástica e regenerar a consolidação. O estudo de quatro malhas fechadas não substitui essa etapa. Mudança numérica altera trajetória via ação/fallback e não é apenas uma troca de rótulo na tabela.

## 6. Integração com a sessão DE2-115

A placa foi recebida pelo autor. Na semana de laboratório: confirmar compilação C, protocolo e referência software antes do ensaio físico. Fixar primeiro qual QP/escala/precisão/horizonte o ADMM resolve; analisar rho e tolerâncias no problema correspondente. Não transportar a escolha de quadprog sem validação do ADMM.

Coletar no hardware: ação e estados por passo; resíduos quando disponíveis; fallback; tempo de solver e ciclo total; primeira amostra e regime; atrasos/erros UART; overruns e saturações; versão e hash de firmware/bitstream. Fotografias e logs devem permitir verificar execução real. Usar `../HANDOFF_DE2115.md` e os scripts em `07_fpga/revisao_operacional/`.

## 7. Critério de fechamento para redação

Decisão explícita da versão adotada; tabelas coerentes com essa versão; incertezas numéricas e escopo de validação registrados; nenhuma promessa apresentada como resultado. A preparação documental pode ser encerrada antes da bancada, mas a seção de hardware permanece pendente.
