# Resultados e argumentos para redação posterior

Base: `05_resultados/revisao_operacional/consolidacao_corrigida_20260911_v1`. As tabelas deste pacote são derivadas dessa base, mantendo a ablação e o experimento numérico separados. Esta orientação não é a redação final de conclusões nem a carta aos revisores.

## Método e contribuição

Descrever uma estratégia MPC aplicada a uma planta agregada, com informação disponível explicitada, preparação de eventos, comparação de cinco políticas e análise de incerteza/custo de reserva. O competidor por cenários é uma implementação deste projeto com comando compartilhado, não reprodução de um algoritmo específico da literatura nem MPC multietapas com recourse. A comparação com a literatura continua necessária para fundamentar novidade.

## Atendimento nominal e limite físico

Perda da fonte: pico heurístico 592,612 kW; determinístico 350,067 kW; estocástico corrigido 350,000 kW. O mínimo persistente de 350 kW decorre de 750 kW de carga e 400 kW máximos do BESS. Por 150 s, resulta em 14,5833 kWh. A redução de aproximadamente 40,9% do pico pelo determinístico corresponde a cerca de 1,16% de energia não atendida. Não descrever isso como eliminação do déficit durante falta.

## Fairness e ablações

Míope em faixas com limites 120/200/400: 102,783/71,305/≈0 kW. O horizonte não é condição necessária para déficit praticamente nulo nesse caso. Com limite 400, múltiplos bursts e NVML ainda favorecem o MPC. A política de rampa em emergência contém exceções.

Ablação isolada: retirar apenas a desigualdade leva perda da fonte de 350,067364 a 350,129102 kW; a ablação antiga dava 351,634708 kW. Nos cinco cenários sem interrupção, todos os picos permanecem abaixo de 1 kW. Não sustentar que a desigualdade é indispensável ou o principal mecanismo do ganho. Mantê-la pode ser justificável, mas sua contribuição marginal foi pequena sob as demais regras preservadas. Fallback permanece na política e também pode responder à alteração das restrições.

Sem previsão futura, perda da fonte chega a 592,555 kW. Nos bursts: 42,808 kW sem previsão, 27,851 kW com horizonte unitário e 0,018 kW completo. Esses testes sustentam o valor da estratégia antecipativa, sem provar atribuição exclusiva a uma única componente.

## Perfis e generalização

Nas 20 janelas NVML: energia média não atendida 6,321 kWh heurístico, 3,134 míope, 0,00042 determinístico e cerca de 0,00008 estocástico. Máximos MPC não são sempre zero: até 3,906 kW determinístico e 3,857 kW estocástico. Picos acima de 1 kW nesses métodos nas janelas NVML ocorreram no primeiro passo.

DIPLOEE é simulado; NVML é potência GPU medida, agregada e reescalada. Interpolação e reescala por janela, sobreposição e seleção por amplitude devem constar. Não tratar amplitude original máxima como pior caso garantido após normalização, nem chamar janelas de instalações independentes.

## Robustez corrigida

Monte Carlo (200 realizações): determinístico pico médio/p95/máximo = 359,052/384,820/580,324 kW; estocástico = 350,009/350,027/350,673 kW. Estocástico reduz pico em 188 casos, empata em 12, não piora em nenhum, com tolerância 0,001 kW. Diferença média estocástico−determinístico = -9,043 kW, IC bootstrap95% [-14,017;-4,791] kW. Diferença mediana de apenas -0,157 kW: benefício concentrado nas realizações mais desfavoráveis.

SOC final médio: 54,998% determinístico e 48,669% estocástico; menor no estocástico em todos os 200 pares. Throughput médio: 31,474 e 56,169 kWh. Energia não atendida média adicional evitada: 0,007515 kWh. Houve três pioras minúsculas de energia no estocástico, maior 0,00003344 kWh. Não declarar dominância geral ou economia de bateria.

Zero picos piores que o heurístico em 200 ensaios não é risco zero: limite superior binomial95% bilateral 1,83%, condicionado à distribuição assumida. O sweep cobre ±20 s; os sorteios efetivos ficaram entre -14 e +16 s. Todas as realizações Monte Carlo usam o mesmo cenário físico com erros de previsão diferentes.

Em +20 s, picos determinístico/estocástico = 511,757/352,424 kW. Gate arm8 piora o desempenho em +10 s. Probabilidades 50/25/25 mantêm picos próximos; no caso de perda, SOC estocástico sobe apenas cerca de 0,185 pp frente às probabilidades iguais. Isso não resolve o custo de reserva.

## Limites operacionais

Falso alarme: estocástico SOC final 49,421%, heurístico 60%, ambos sem déficit. Evento não previsto: determinístico ≈592,555 kW. Atraso de detecção: determinístico ≈749,906 kW de pico. Não confundir previsão com detecção nem atribuir melhoria histórica à otimização quando o protocolo de informação mudou.

SOC inicial 30%: estocástico chega a cerca de 20,002%; falta evidência sobre segundo evento antes da recarga. Falta prolongada: ambos pico 750 kW e SOC mínimo20%; MPC deixa 2,377 kWh a mais de energia não atendida. Continuidade depende de potência/energia instaladas e recursos que não constam da planta agregada.

## Solução numérica e bancada

Usar `DIAGNOSTICO_NUMERICO.md`. A reescala é candidata, não parte dos resultados principais. Relatar 3 overruns de inicialização no estocástico e nenhum no determinístico, sem extrapolar para a placa. DE2-115 disponível; validação física pendente. Oito ensaios SIL existentes são apoio, não HIL.

## Organização sugerida das evidências no artigo

1. Modelo e formulação: convenções, preditores, QP, supervisão/fallback e hipóteses dos cenários.
2. Protocolo: informação corrente/futura, dataset, janelas, condições iniciais, limites e sementes.
3. Comparação principal: cinco competidores, pico e energia, com SOC/throughput ao lado.
4. Ablações e fairness: separar ajuste de comando, previsão, horizonte e desigualdade.
5. Robustez: sweep, Monte Carlo, alarmes, detecção e reserva.
6. Diagnóstico numérico: causas observadas, experimento de escala, limitações e decisão da versão final.
7. Hardware: inserir somente após coleta e validação física, com ciclo total e evidência de execução.
8. Discussão: limites, casos de perda/empate e ausência de garantia universal.

O confronto comentário a comentário com os cinco revisores permanece etapa posterior; não marcar comentários atendidos apenas por terem material neste pacote.
