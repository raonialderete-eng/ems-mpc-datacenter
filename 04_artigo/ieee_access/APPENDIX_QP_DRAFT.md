# Appendix draft — MPC-QP (Phase 1)

Equations already implemented in `01_matlab_base/controle_mpc_qp_v5.m`. To be typeset in the Access appendix (Phase 3).

Decision vector, dimension \(n_z = N_c + 5 N_p\) (nominal \(15+5\cdot 60 = 315\)):

\[
z = [\Delta U;\ P_{\mathrm{grid}};\ S_{\mathrm{load}};\ S_{\mathrm{source}};\ S_{\mathrm{rech}};\ S_{\mathrm{event}}].
\]

Reference reconstruction:

\[
u_{k+i|k} = u(k-1) + \sum_{j=0}^{\min(i,N_c-1)}\Delta u_{k+j|k}.
\]

BESS map: \(P_{\mathrm{BESS}}(k+1)=a_b P_{\mathrm{BESS}}(k)+b_b u(k)\), \(a_b=e^{-T_s/\tau_b}\), \(b_b=1-a_b\).

SOC predictor (successive linearization on the free response): \(K_{\mathrm{d}}=T_s\cdot 100/(3600 E_{\mathrm{bat}}\eta_{\mathrm{d}})\), \(K_{\mathrm{c}}=T_s\eta_{\mathrm{c}}\cdot 100/(3600 E_{\mathrm{bat}})\). Sign of \(P_{\mathrm{BESS}}^{\mathrm{free}}\) selects the branch; QP stays convex.

Balance: \(P_{\mathrm{grid},i}+P_{\mathrm{BESS},i}+S_{\mathrm{load},i}=P_{\mathrm{load},i}\), with \(g_i=0\Rightarrow P_{\mathrm{grid},i}=0\).

Event inequality: \(P_{\mathrm{BESS},i}+S_{\mathrm{event},i}\ge P_{\mathrm{BESS},i}^{\min,\mathrm{evt}}\).

Confirmation (revision): if \(\mathrm{event\_arm\_horizon}=N_{\mathrm{arm}}<\infty\), the event constraint and \(\Delta u_{\max}^{\mathrm{evt}}\) are applied only when the predicted event is within \(N_{\mathrm{arm}}\) steps or has already started. Default \(N_{\mathrm{arm}}=\infty\) reproduces the submitted paper.

Bounds: \(u\in[P_{\mathrm{BESS}}^{\min},P_{\mathrm{BESS}}^{\max}]\), \(\Delta u\in[-\Delta u_{\max},\Delta u_{\max}]\), slacks \(\ge 0\), SOC in \([\mathrm{SOC}_{\min},\mathrm{SOC}_{\max}]\).

Normalization in the cost: powers by \(P_{\mathrm{base}}\) (source limit), ramps by \(R_{\mathrm{base}}\), SOC by \(100\%\). Hessian regularized by \(10^{-6}I\). `condest(H)` logged on the first QP of each campaign run.

Weight hierarchy (nominal): \(w_L=w_E=10^9\), \(w_G=10^8\), \(w_C=10^6\), tracking/SOC/ramps/BESS/\(\Delta u\) as in Table weights of the manuscript.
