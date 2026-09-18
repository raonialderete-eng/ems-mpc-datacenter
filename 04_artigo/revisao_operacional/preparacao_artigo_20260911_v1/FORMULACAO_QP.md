# Formulação correspondente ao código executado

Fontes: `01_matlab_base/parametros.m`, `planta_bess.m`, `revisao_operacional/montar_qp_auditado.m`, `controle_mpc_auditado.m`, `simular_ems_auditado.m` e `metricas_auditadas.m`. A função objetivo abaixo descreve o código; não é uma reformulação idealizada.

## 1. Convenções e planta

Tempo de amostragem $T_s=1$ s. $u_k$ é referência BESS em kW; $p_k$ é potência BESS; $s_k$ é SOC em porcentagem. Descarga é positiva. $L_k$ é carga, $M_k$ é limite da fonte e $G_k\in\{0,1\}$ indica sua disponibilidade. $E_b=500$ kWh, $\eta_d=\eta_c=0{,}95$, $p_{\min}=-250$ kW, $p_{\max}=400$ kW, $s_{\min}=20\%$, $s_{\max}=90\%$.

Medição em $k$ → cálculo de $u_k$ → potência $p_{k+1}$ → balanço do intervalo $k$ → $s_{k+1}$. Portanto, a primeira previsão de potência BESS equilibra a carga medida $L_k$, não $L_{k+1}$.

$$a=e^{-T_s/\tau_b},\quad b=1-a,\qquad p_{k+1}=a p_k+b u_k.$$

A planta implementa saturação de comando e potência, bloqueio de descarga/carga nos limites de SOC e saturação final do SOC. As equações lineares preditivas não incluem todas essas proteções não lineares.

$$P_{g,k}=\begin{cases}\min\{M_k,\max(0,L_k-p_{k+1})\},&G_k=1,\\0,&G_k=0,\end{cases}\qquad
P_{u,k}=\max(0,L_k-P_{g,k}-p_{k+1}).$$

$$s_{k+1}=s_k-\frac{100T_s}{3600E_b}\begin{cases}p_{k+1}/\eta_d,&p_{k+1}\ge0,\\\eta_c p_{k+1},&p_{k+1}<0.\end{cases}$$

Esta última expressão é seguida pela saturação na planta. Fonte limitada por saturação não demonstra, por si só, restrições respeitadas pelo QP.

## 2. Predição condensada

$N_p=60$, $N_c=15$. Índice $i=1,\ldots,N_p$ representa o comando do intervalo $k+i-1$ e a potência BESS no estado $k+i$. O comando é mantido após o horizonte de controle.

$$\Delta U=[\Delta u_1,\ldots,\Delta u_{N_c}]^T,\quad U=\mathbf1u_{k-1}+T\Delta U,\quad T_{ij}=\mathbb1(j\le i).$$

$$P=\Phi p_k+\Gamma U=P^0+\Gamma T\Delta U,\qquad
\Phi_i=a^i,\quad \Gamma_{ij}=\begin{cases}ba^{i-j},&j\le i,\\0,&j>i.\end{cases}$$

Seja $C=\operatorname{tril}(\mathbf1\mathbf1^T)$. A linearização SOC escolhe o ramo pelo sinal da resposta livre $P^0$, calculada com o comando anterior mantido:

$$K_i=\frac{100T_s}{3600E_b}\begin{cases}1/\eta_d,&P_i^0\ge0,\\\eta_c,&P_i^0<0,\end{cases}\qquad
S=\mathbf1s_k-C\operatorname{diag}(K)P.$$

Se a solução mudar o sinal da potência em relação à resposta livre, o preditor deixa de coincidir com a integração por trechos. Reportar o erro contra essa referência, sem confundi-lo com erro acumulado de SOC físico. Os estados são eliminados analiticamente; não são variáveis de decisão explícitas.

## 3. Variáveis e objetivo

$$z=[\Delta U;P_g;\xi_L;\xi_G;\xi_R;\xi_E],\qquad n_z=N_c+5N_p=315.$$

Cada vetor auxiliar tem $N_p$ elementos. $\xi_L$ representa déficit previsto, $\xi_G$ relaxa o limite da fonte, $\xi_R$ relaxa a recarga e $\xi_E$ relaxa o suporte ao evento. Todas são não negativas.

Com $P_b=950$ kW, $R_b=100$ (diferença de potência por amostra, equivalente a kW/s para $T_s=1$ s), referência de SOC $s^\star=60\%$ e operador de diferença $D$:

$$\begin{aligned}
J(z)={}&w_g\|(P_g-P_g^\star)/P_b\|_2^2
+w_L\|\xi_L/P_b\|_2^2+w_G\|\xi_G/P_b\|_2^2\\
&+w_R\|\xi_R/P_b\|_2^2+w_E\|\xi_E/P_b\|_2^2
+w_r\|(DP_g-e_1P_{g,k-1})/R_b\|_2^2\\
&+w_s\|(S-\mathbf1s^\star)/100\|_2^2
+w_T((S_{N_p}-s^\star)/100)^2\\
&+w_p\|P/P_b\|_2^2+w_u\|\Delta U\|_2^2+\frac{\epsilon}{2}\|z\|_2^2.
\end{aligned}$$

**O termo $w_u\|\Delta U\|^2$ não é dividido por $P_b^2$ no código.** A regularização é $\epsilon=10^{-6}$ adicionada à Hessiana, logo sua contribuição ao custo é $\epsilon\|z\|^2/2$.

| Peso | Valor normal | Modo evento |
|---|---:|---:|
| $w_g$ | 3000 | 3000 |
| $w_L$ | $10^9$ | $10^9$ |
| $w_G$ | $10^8$ | $10^8$ |
| $w_R$ | $10^6$ | $10^6$ |
| $w_E$ | $10^9$ | $10^9$ |
| $w_r$ | 300 | 75 |
| $w_s$ | 1200 | 1200 |
| $w_T$ | 12000 | 12000 |
| $w_p$ | 20 | 2 |
| $w_u$ | 50 | 5 |

O QP enviado ao solver é $\min_z\frac12z^THz+f^Tz$, sujeito a $Az\le b_A$, $Ez=d$, $\ell\le z\le h$. Para cada termo $w\|Fz+c\|^2$, acumula-se $H\leftarrow H+2wF^TF$ e $f\leftarrow f+2wF^Tc$. Constantes independentes de $z$ são omitidas.

## 4. Restrições

Para todo passo previsto:

$$P_{g,i}+P_i+\xi_{L,i}=\widehat L_i;\qquad
p_{\min}\le P_i\le p_{\max};\qquad s_{\min}\le S_i\le s_{\max}.$$

$$u_{\min,i}\le U_i\le p_{\max},\quad
u_{\min,i}=\begin{cases}0,&\widehat G_i=0,\\p_{\min},&\widehat G_i=1,\end{cases}\quad
-dU_{\max}\le\Delta U\le dU_{\max}.$$

$$P_{g,i}-\xi_{G,i}\le\widehat M_i,\quad P_{g,i}\ge0;\qquad P_{g,i}=0\ \text{se}\ \widehat G_i=0.$$

Se houver recarga solicitada: $P_{g,i}+\xi_{R,i}\ge P_{g,i}^{\min,R}$. Se houver suporte positivo ao evento: $P_i+\xi_{E,i}\ge q_i$. Sem esses pedidos, as respectivas folgas são fixadas em zero. Com fonte ausente, folgas de fonte e recarga também são fixadas em zero. Não há limite rígido de rampa da fonte: esse comportamento é penalizado no custo. Limite de comando não é a mesma coisa que rampa física de $p_k$.

## 5. Evento, referência e fallback

O alvo bruto é $v_i=\min(\widehat L_i,400)$ durante falta; com fonte disponível, $v_i=\min(\max(\widehat L_i-\widehat M_i,0),400)$. O primeiro $v_i>0$ identifica $i_e$. A confirmação depende de `event_arm_horizon` e `event_min_duration`; valores principais são infinito e 1.

Se armado, $q_i=v_i$ para $i\ge i_e$. Antes, com $d=i_e-i\le30$, $q_i=(30-d+1)v_{i_e}/30$; fora dessa janela, $q_i=0$. Se não armado, todo $q_i=0$.

A referência da fonte é zero em falta; $\max(0,\widehat L_i-q_i)$ quando há suporte; $\widehat M_i$ se a carga excede o limite sem suporte; e $\widehat L_i$ nos demais casos. Somente sem evento armado, com SOC abaixo de 59,7% e folga da fonte, solicita-se recarga de até $\min(\widehat M_i-\widehat L_i,50,250)$ kW e eleva-se referência/limite mínimo de recarga.

Em modo evento, $dU_{\max}$ passa de 120 a 400 kW/amostra na configuração principal, além dos ajustes de pesos. A campanha fairness fixa valores comuns de 120/200/400, mas a camada supervisória contém bypass durante falta. Não alegar equivalência absoluta de política de emergência.

Se `exitflag<=0` ou solução vazia, aplica-se fallback: suporte máximo permitido na falta; suporte nominal de evento com limitador quando aplicável; ou heurístico com limitador. Proteções de SOC e saturação também operam após o QP. A política de fallback integra o método avaliado.

Na ablação isolada, somente as linhas $P_i+\xi_{E,i}\ge q_i$ são removidas. $q_i$, referências, custos, limites e fallback são preservados. As variáveis de folga permanecem no QP. A ablação antiga também alterava referências e não isola essa desigualdade.

## 6. Formulação por cenários

Para $s\in\{nominal,carga\ alta,evento\ adiantado\}$:

$$\min_{\Delta U,y_1,y_2,y_3}\sum_s\pi_s J_s(\Delta U,y_s),\qquad \pi_s=1/3.$$

Cada cenário tem seus auxiliares $y_s=[P_g^s;\xi_L^s;\xi_G^s;\xi_R^s;\xi_E^s]$ e suas restrições. A sequência **inteira** $\Delta U$ é compartilhada. Os limites compartilhados são intersectados. Não existe ramificação futura de comandos nem recourse por cenário. Como a dinâmica BESS/SOC e a condição inicial são comuns, esses estados previstos condensados coincidem para comandos iguais; são os auxiliares da fonte/carga e as exigências que dependem do cenário.

Amostra corrente medida é comum. Carga alta: $1,2\widehat L_i$ somente para $i\ge2$, sem truncamento em 950 kW. Evento adiantado: apenas interrupções anunciadas visíveis são deslocadas 10 s; a medição corrente não muda. Quando o retorno não está visível, mantém-se indisponibilidade até o fim do horizonte; isso é uma extensão conservadora de informação censurada, não conhecimento do instante exato de retorno. Evento já em curso permanece medido; sem anúncio, o cenário coincide com o nominal.

Cenários duplicados são fundidos somando probabilidades. Dimensão: $N_c+5N_p n_{únicos}$ = 315, 615 ou 915. Apenas $u_k=u_{k-1}+\Delta u_1$ é aplicado, seguido de nova otimização na amostra seguinte. Sensibilidade secundária: probabilidades 0,50/0,25/0,25.

## 7. Métricas e estatística

$$P_u^{\max}=\max_k P_{u,k},\qquad E_u=\frac{T_s}{3600}\sum_k P_{u,k},\qquad
Q=\frac{T_s}{3600}\sum_k|p_{k+1}|,\qquad EFC=Q/(2E_b).$$

Throughput/EFC medem utilização, não vida útil. Integram-se 1.200 intervalos para 1.201 estados; não adicionar intervalo ao endpoint. Métrica filtrada zera $P_u<\max(1,0{,}001\max L)$ kW. Recuperação: primeiro início de uma sequência de pelo menos 10 s abaixo de 1 kW após cada início de evento; ausência é NaN. Recuperação zero não significa déficit zero durante todo o ensaio, nem 10 s de espera até declarar sua ocorrência.

Monte Carlo: 200 realizações pareadas de erro de previsão, carga física constante de 750 kW e uma falha física fixa. Deslocamento temporal normal de desvio 6 s, limitado a ±20 s e arredondado; fator de carga uniforme em [0,8;1,2]. Diferença de picos usa tolerância 0,001 kW na classificação. IC da média por bootstrap pareado, 2.000 reamostragens, semente 20260911; frequência com IC binomial exato bilateral de 95%. São hipóteses de ensaio, não distribuição empiricamente identificada de falhas.
