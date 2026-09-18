## Preparação técnica para o artigo — fechamento em 13/09/2026

Pacote `preparacao_artigo_20260911_v1/`: formulação conferida contra o código, diagnóstico numérico, interpretação dos resultados e procedimento para ampliar a validação. Inclui cinco tabelas e 13 blocos de equações em LaTeX, CSVs de evidência e manifesto de hashes. Os fragmentos precisam de integração e revisão de diagramação no manuscrito. Nenhum resultado de reescala foi incorporado automaticamente à comparação principal.

A DE2-115 já está com o autor; comunicação, firmware e ensaios físicos permanecem pendentes. O guia de laboratório foi atualizado, com cópia anterior preservada. Este fechamento é documental: não equivale a nova campanha, aprovação de todos os comentários dos revisores ou validação física. Ver `preparacao_artigo_20260911_v1/FECHAMENTO_20260913.md` para verificações e alterações.

---
## Consolidação corrigida — 11/09/2026

Execução encerrada: campanha original 1.755/1.755, reexecução do evento adiantado 266/266 e ablação isolada 21/21.

A pasta `05_resultados/revisao_operacional/consolidacao_corrigida_20260911_v1/` reúne 1.489 casos não afetados e 266 resultados corrigidos, com proveniência e hashes por caso. A ablação de 21 casos permanece em tabela separada. Picos, energias e balanço foram recalculados nas séries; os 200 pares Monte Carlo usam as mesmas trajetórias físicas; entradas e parâmetros das reexecuções coincidem com os originais. Integridade: 3.508 arquivos históricos inalterados e 42 perfis verificados.

Monte Carlo corrigido: pico médio/p95/máximo estocástico = 350,008665/350,027338/350,672794 kW. Frente ao determinístico: pico menor em 188 realizações e empate em 12 (tolerância 0,001 kW); SOC final menor em todas as 200, com diferença média de -6,329763 pontos percentuais. Throughput médio adicional: 24,695241 kWh. Não há dominância geral em energia/SOC/utilização da bateria.

A ablação isolada indica contribuição marginal pequena da desigualdade de evento nos cenários avaliados. Experimentos separados de escala do solver (16 replays aprovados e quatro malhas fechadas) apoiam hipótese de sensibilidade numérica, mas não substituem a campanha principal nem demonstram solução universal. A tentativa anterior que falhou também foi preservada.

Pendências científicas e operacionais: validação mais ampla da escala do solver se adotada, interpretação das exceções de rampa, limites de generalização dos perfis e protocolo, hardware DE2-115, confronto individual com os revisores e redação/handoffs após discussão. Três ciclos estocásticos acima de 1 s ocorreram no primeiro passo dos respectivos casos; não alegar ausência de overruns ou validação física.

---
## Atualização — 11/09/2026, 07:23 (America/Cuiaba)

Campanha corrigida `evento_adiantado_corrigido_v1`: **74/266 casos (27,8%)**, MATLAB ativo no caso j00801, 11ª realização estocástica do Monte Carlo. Restam 192 casos.

Concluídos: principal 2/2; fairness 6/6; timing 41/41; magnitude 5/5; falso alarme 1/1; sensibilidade da planta 9/9. Monte Carlo corrigido: 10/200. Probabilidades: 0/2.

A campanha original de 1.755 casos e a ablação isolada de 21 casos permanecem concluídas e preservadas. Os resultados estocásticos históricos com interrupção anunciada devem ser identificados como anteriores à correção. A nova campanha reutiliza os mesmos casos físicos e parâmetros, com código congelado e verificação de hashes. A interrupção anterior foi explicada pelo usuário: o computador desligou.

Ainda faltam completar e analisar a reexecução, atualizar as conclusões científicas e depois os handoffs. Esta atualização substitui os contadores históricos abaixo, sem declarar validação científica concluída.

---
## Encerramento computacional — 10/09/2026, 16:22 (America/Cuiaba)

**1.755/1.755 casos executados.** Todos os grupos concluídos, incluindo 200 realizações pareadas do Monte Carlo (1.000 simulações), sete casos de probabilidades e dois de interrupção prolongada. MATLAB encerrado e lock removido normalmente.

O pipeline registrou `completed_execution` às 16:22:52. Consolidação automática em `05_resultados/revisao_operacional/analise_final_20260910_065326/`. Integridade final: 3.508 arquivos originais conferidos, nenhuma alteração; 42 perfis verificados.

Status: **execução e consolidação automática concluídas**. A validação científica integral, a revisão das interpretações e a atualização final dos handoffs continuam pendentes. Compilação C e validação física permanecem separadas. Não interpretar a conclusão computacional como aprovação para o artigo.

Esta atualização substitui os contadores históricos abaixo. Versão anterior preservada em `.bak`.

---
## Atualização de 10/09/2026, 14:02 (America/Cuiaba)

Campanha ativa, MATLAB PID 15944. Resultados completos: **1.405/1.755 (80,1%)**. Último caso iniciado no log: j01406, MPC estocástico na realização 132 do Monte Carlo.

- Monte Carlo novo: 659/1.000 simulações; 131 realizações completas com cinco competidores e quatro casos da realização 132.
- Todos os grupos anteriores, incluindo as 200 simulações das janelas adicionais, terminaram de executar.
- Restam 341 simulações do Monte Carlo, 7 de probabilidades e 2 de interrupção prolongada: 350 casos.
- Ainda não há evento de encerramento do pipeline. Consolidação final, validação científica e atualização final dos handoffs permanecem pendentes.

Esta fotografia substitui os contadores das atualizações abaixo. Execução concluída não equivale a validação científica nem a aprovação para incorporação ao artigo. Atualização documental com cópia anterior preservada em `.bak`; sem alteração de código ou resultados.

---
## Atualização de 10/09/2026, 09:10 (America/Cuiaba)

Campanha `campanha_v1`: **555/1.755 casos executados (31,6%)**, com 1.200 restantes. MATLAB ativo, PID 15944; o log iniciou j00556. Esta é uma fotografia do andamento, não um contador em tempo real.

| Grupo | Executados / previstos |
|---|---:|
| Comparação principal | 35/35 |
| Limites comuns (fairness) | 105/105 |
| Ablações | 28/28 |
| Pesos | 30/30 |
| Erro temporal | 205/205 |
| Gate | 3/3 |
| Erro de carga | 25/25 |
| Alarmes/eventos | 10/10 |
| Atraso de detecção | 15/15 |
| Sensibilidade da planta e SOC inicial | 90/90 |
| Janelas adicionais | 9/200 |
| Monte Carlo pareado | 0/1.000 |
| Probabilidades do estocástico | 0/7 |
| Interrupção prolongada | 0/2 |

**Executado** significa resultado completo salvo. Os grupos recentemente terminados ainda precisam de análise de resíduos, fallback, métricas e comparações antes de serem marcados **validados** ou **prontos para incorporação ao artigo**. O pipeline ainda não registrou encerramento nem análise final.

Restam terminar as janelas, as 200 realizações pareadas com cinco controladores, a sensibilidade das probabilidades e os dois casos de interrupção prolongada. Depois: revisar a consolidação automática e atualizar os handoffs. Compilação C e validação física continuam pendentes, conforme o escopo registrado.

Registro atualizado somente para corrigir a fotografia desatualizada do progresso. A versão anterior deste documento foi preservada em arquivo `.bak` com data e hora. Nenhum código, configuração ou resultado experimental foi alterado nesta atualização.

---
# Andamento operacional

## Concluído e verificado nesta implementação

- Inventário: 3.508 arquivos históricos conferidos, nenhuma alteração.
- Dataset local: 42 perfis derivados em pasta nova, hashes e correspondência MAT/CSV verificados.
- Código auditado: builder V5, simulador causal, métricas brutas/filtradas e estocástico de três cenários implementados.
- Testes iniciais: equivalência V5, cenários idênticos, factibilidade do caso de teste, dimensão do QP, indexação da planta, ausência de antecipação e medição corrente aprovados.
- Comparação principal: 35 simulações concluídas; tabelas e figura em `analise_principal_01`.
- Warm-start: 20 chamadas com solução/iterações iguais; resultado e documentação registrados.
- Preparação da bancada: parser MATLAB testado e oito execuções SIL feitas com o novo registrador por sessão.
- Pacote C/Quartus/Nios e guia preparados. Compilação C e execução física não realizadas.
- Matriz com 53 comentários e handoffs para artigo e laboratório criados.

## Campanha extensa

O pipeline da `campanha_v1` foi iniciado para executar todos os grupos restantes e produzir uma análise final automaticamente. A comparação principal já concluída é retomada por checkpoint, sem repetição.

Consultar o estado efetivo:

```powershell
python ./04_artigo/revisao_operacional/status_campanha.py --run campanha_v1
```

O script de status usa apenas a biblioteca padrão Python. A execução longa depende de o computador e o processo MATLAB permanecerem disponíveis. Os arquivos completos são preservados em interrupção; retomar pelo pipeline com a mesma impressão digital.

Logs de estado do pipeline: `05_resultados/revisao_operacional/pipeline_*.jsonl`.
Logs de jobs: `05_resultados/revisao_operacional/campanha_v1/log_*.txt`.
O evento `completed_execution` confirma execução e análise automatizada, não aprovação científica de todos os resultados.

Não marcar Monte Carlo, sweep ou fairness como concluídos com base neste documento: consultar seus contadores. O programa registra 1.755 jobs no total, dos quais 1.000 correspondem às 200 realizações vezes cinco controladores.

## Pendências após computação

- Examinar resultados finais e atualizar a interpretação de cada comentário.
- Compilar C/ADMM com compilador disponível e executar testes de integração.
- Validar fisicamente na DE2-115.
- Redigir artigo e carta com os resultados consolidados.

## Correções futuras já sustentadas

Não alegar warm-start efetivo no IPM; não chamar DIPLOEE de medição de instalação; não tratar zero filtrado como zero matemático. O estocástico reduziu alguns resíduos/picos, mas consumiu mais SOC nos casos principais. Ver `ACHADOS_EXECUTADOS_01.md` antes de formular conclusões.





