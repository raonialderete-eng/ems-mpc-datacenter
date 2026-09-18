# Referências metodológicas verificadas nesta implementação

## Solver

A documentação oficial de [quadprog](https://www.mathworks.com/help/optim/ug/quadprog.html) informa que `interior-point-convex` ignora o ponto inicial `x0`. O código público local encaminha esse argumento às rotinas internas, mas isso não demonstra aproveitamento. O teste no R2025b produziu 12 iterações e solução idêntica em todas as 20 chamadas, alternando `x0=[]` e uma solução ótima anterior. Tempos isolados variam e não provam aceleração. Evidência local: `05_resultados/revisao_operacional/warmstart_v1.csv`.

A documentação de [warm-start](https://www.mathworks.com/help/optim/ug/warm-start-best-practices.html) descreve o uso do objeto apropriado com active-set. Não foi trocado o algoritmo para obter uma comparação favorável.

## MPC por cenários

A documentação primária do projeto [do-mpc sobre MPC e cenários](https://www.do-mpc.com/en/v4.1.0/theory_mpc.html) descreve predições sob realizações alternativas e restrições de não antecipação. O artigo [Robust Model Predictive Control via Scenario Optimization](https://arxiv.org/abs/1206.0038) é uma referência primária adicional para formulações por cenários.

O competidor implementado aqui é uma formulação finita de custo esperado com sequência de comandos compartilhada. Não implementa a árvore multietapas do do-mpc nem as garantias probabilísticas do artigo citado. Os três cenários são escolhas de projeto, não amostras suficientes para invocar teoremas de probabilidade de violação. Verificar a referência bibliográfica final e justificar essas diferenças na redação futura.
