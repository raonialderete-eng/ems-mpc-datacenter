# Diagnóstico numérico: evidência e limites

## 1. Situação da versão principal

Solver: quadprog, interior-point-convex, MATLAB R2025b. MaxIterations=150, ConstraintTolerance=1e-5, OptimalityTolerance=1e-5, StepTolerance=1e-8; chamada com X0 vazio. Não alegar warm-start efetivo. A versão corrigida modifica somente a construção do evento adiantado. Reescala de objetivo ainda é experimento separado.

| Método | Passos na consolidação | Fallbacks | Causas registradas |
|---|---:|---:|---|
| Míope | 404.400 | 444 | -2 |
| MPC determinístico | 487.200 | 6.261 | 6.254 com -6; 3 com 0; 4 com -2 |
| Estocástico | 412.800 | 653 | -6 |

Não comparar esses totais como probabilidades entre métodos: há números e grupos de ensaio diferentes. Para comparação pareada, usar Monte Carlo: fallback médio por ensaio 1,82125% determinístico e 0,240833% estocástico. Falha -6 é o diagnóstico emitido pelo solver; não prova que a planta seja inviável nem, isoladamente, que a Hessiana montada seja matematicamente indefinida.

Resíduo máximo de igualdade entre soluções aceitas: 0,00791795 kW determinístico e 0,00783103 kW estocástico. Desigualdades máximas: 1,4373e-7 e zero, respectivamente, na métrica implementada. Não confundir resíduos de tentativas rejeitadas com a ação aplicada por fallback. Campos não medidos nos heurísticos/míope não devem ser apresentados como zeros de validação.

Erro máximo do preditor SOC em soluções aceitas: 0,120044 pp determinístico e 0,132541 pp estocástico. A escolha do ramo pelo sinal da resposta livre permanece aproximação. A planta saturou SOC inferior em um passo de cada caso prolongado (heurístico e determinístico); respeito do SOC final aos limites não é prova independente de viabilidade da previsão.

## 2. Hipótese e efeito da escala

$$\min_z J(z)=\tfrac12 z^THz+f^Tz\quad\Longleftrightarrow\quad\min_z \alpha J(z),\qquad \alpha>0.$$

Em aritmética exata, multiplicar **H e f** pelo mesmo escalar positivo não muda os minimizadores, as restrições nem os pesos relativos. Entretanto, a convergência numérica e tolerâncias absolutas podem mudar. Também não reduz o número de condição ideal: $\kappa(\alpha H)=\kappa(H)$. Não escrever que a reescala necessariamente melhorou o condicionamento da Hessiana.

Regularização $H+\epsilon I$, reescala de variáveis e reescala global do objetivo são operações diferentes. A primeira muda o problema; a segunda exige transformar todas as matrizes/limites consistentemente; a terceira é a candidata aqui testada.

## 3. Experimentos existentes

Tentativa `solver_escala_20260910_194722_777`: critério de replay não aprovado; malhas fechadas não iniciadas. Preservar e relatar que a escala não assegurou aprovação com todas as tolerâncias tentadas.

Experimento `solver_escala_20260910_194805_009`:

- 16 instantes de falha selecionados de quatro arquivos; não são amostra representativa de todos os modos de falha.
- Escala candidata 0,001 e tolerância de optimalidade 1e-5.
- Referências active-set com escalas 0,001 e 0,01, tolerância de optimalidade 1e-8, restrição 1e-7 e passo 1e-12. As referências usam a solução candidata como inicialização; são checagens cruzadas, não ensaios totalmente independentes.
- Cholesky da Hessiana passou nos 16 QPs. A escala candidata retornou solução aprovada nos 16. Maior diferença da primeira ação para referências: cerca de 0,09643 kW; critério do experimento: <0,1 kW. Não traduzir esse critério em igualdade exata de toda a sequência ou do custo.
- Os resíduos de viabilidade dos replays aprovados ficaram próximos de 1e-13 na métrica implementada; são estados específicos, não limite global da campanha.
- Quatro malhas fechadas: perda da fonte, dois métodos, escala ativada/desativada. Determinístico: fallback 19→0; pico 350,067364→350,000303 kW; SOC final 57,097660→56,697553%; throughput 27,741904→29,385379 kWh. Estocástico: ambos sem fallback e indicadores muito próximos.
- Tempos desse experimento foram coletados com concorrência de processos; não usá-los para alegações de desempenho computacional.

Interpretação permitida: há evidência forte de sensibilidade numérica nos QPs examinados. Não há, ainda, validação universal da escala nem justificativa para trocar os resultados principais pelos quatro ensaios auxiliares.

## 4. Resíduos a registrar na ampliação

Para $Az\le b$, $Ez=d$, $\ell\le z\le h$, definir:

$$r_p=\max\{0,\max(Az-b),\|Ez-d\|_\infty,\max(\ell-z),\max(z-h)\}.$$

Essa expressão mistura unidades quando aplicada às matrizes brutas. Além do máximo legado, separar igualdade de potência (kW), SOC (pp), comandos (kW) e resíduos relativos por linha. O resíduo de uma linha pode ser normalizado por $1+|b_i|+\|A_i\|_1\|z\|_\infty$, registrando a convenção e evitando comparar tolerâncias incompatíveis.

Com multiplicadores de desigualdade $\lambda$, igualdade $\nu$ e limites $\mu_\ell,\mu_h$:

$$r_d=\|\alpha(Hz+f)+A^T\lambda+E^T\nu-\mu_\ell+\mu_h\|_\infty.$$

$$r_c=\max\{\|\lambda\odot(Az-b)\|_\infty,\|\mu_\ell\odot(\ell-z)\|_\infty,\|\mu_h\odot(z-h)\|_\infty\}.$$

Somente limites finitos participam de $r_c$. Verificar não negatividade dos multiplicadores pertinentes. Os multiplicadores e tolerâncias devem corresponder ao problema escalado; comparar em unidades originais requer desfazer a escala. Registrar também custo original, primeira ação, erro relativo da sequência e mensagens completas do solver.

O experimento de 16 replays não armazenou uma verificação completa de complementaridade e todos esses critérios. Eles são requisitos para a próxima etapa, não resultados já obtidos.

## 5. Computação e evidência embarcada

Consolidação: determinístico máximo de ciclo 0,5654008 s, sem overruns; estocástico máximos de inicialização 1,1688671 s (j00154), 1,1408007 s (j00253) e 1,2380995 s (j00363). Os três estão no passo zero. Maiores p95 por caso: 68,8652 ms e 106,4073 ms. Não são percentis agregados de todos os passos nem WCET demonstrado.

A escala do QP resolvido por quadprog não valida automaticamente C/ADMM, precisão fixa, UART ou prazo em FPGA. A DE2-115 já está disponível com o autor; os ensaios físicos permanecem pendentes. O controlador embarcado continua sendo o horizonte reduzido previsto, não o estocástico.

## 6. Linguagem para o artigo

Permitido: “Os replays selecionados indicaram sensibilidade do solver à escala do objetivo; a reescala positiva preserva o problema matemático, mas altera o comportamento numérico observado.”

Evitar: “Todas as falhas eram falsas”, “a escala resolveu o solver”, “não existe fallback”, “warm-start comprovado”, “tempo real garantido na DE2-115”.

Referências primárias de apoio: [quadprog](https://www.mathworks.com/help/optim/ug/quadprog.html), [tolerâncias](https://www.mathworks.com/help/optim/ug/tolerances-and-stopping-criteria.html). A documentação da versão instalada e os logs devem prevalecer ao descrever o experimento.
