# Tolerâncias ADMM (declaradas a priori)

Congeladas em 2026-09-19 **antes** de alterar `qp_admm.c`.
Não retocar para fabricar \(P_{\mathrm{un}}=0\) / \(351\) kW.

Ensaio de controlador: \(T_s=1\) s, BESS \(400\) kW, limiar de relatório \(1\) kW.
Não são a precisão do IPM (\(\sim 10^{-13}\)).

| Grandeza | Portão | Unidade |
|---|---|---|
| Balanço de potência (restrição, unidades originais) | \(\le 1\) | kW |
| Limites de comando | \(\le 1\) | kW |
| Rampa \(\Delta u\) | \(\le 1\) | kW/s |
| SOC | \(\le 0.05\) | pp |
| \(\lvert\Delta u_0\rvert\) vs \(x^\star\) certificado no mesmo QP | \(\le 0.10\) | kW |
| Custo \(\lvert J-J_{\mathrm{ref}}\rvert/(1+\lvert J_{\mathrm{ref}}\rvert)\) | \(\le 10^{-3}\) | — |
| Estacionariedade relativa \(\lVert Px+q+A^\top\lambda\rVert_2/(\lVert q\rVert_2+\lVert Px\rVert_2)\) | \(\le 10^{-2}\) | — |
| Estacionariedade absoluta | registrar | — |
| `pri_unscaled < 1` | guarda histórica | — |

`pri_tol=1` **não** se afrouxa e **não** aprova sozinho.
`admm_rho=1`, `admm_max_iter=80` (default). Subir o teto de iterações não é correção sem evidência nos dumps.

Versão do solver no freeze: `fase1_hps-P1-20260919-r2` (`VERSION.txt`).
