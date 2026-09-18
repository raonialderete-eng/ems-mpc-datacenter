"""Pre-register remaining experimental jobs. Does not inspect KPIs."""
from pathlib import Path
import json
import numpy as np

HERE = Path(__file__).resolve().parent
SEED = 20260914
CTRL5 = ['heuristico', 'heuristico_foresight', 'miope_qp', 'mpc_qp_v5', 'mpc_qp_estocastico_3cen']
CTRL6 = CTRL5 + ['ff_feedback']
CORE = ['carga_faixas', 'limite_fonte', 'perda_fonte', 'retorno_fonte', 'multi_burst',
        'diploee_facility_stress', 'nvml_llama2_stress']
LOADS = ['carga_faixas', 'multi_burst', 'nvml_llama2_stress']
POLICY = 'persistence'  # A1 still compares; later blocks use the causal persistence default.


def add(jobs, group, scenario, ctrls, **kw):
    params = dict(kw.pop('params', {}) or {})
    if 'information_policy' not in params:
        params['information_policy'] = POLICY
    for ctrl in ctrls:
        jobs.append(dict(id=f'{group}_{len(jobs)+1:04d}', group=group, scenario=scenario,
                         ctrl=ctrl, params=params, **{k: v for k, v in kw.items()}))


def main():
    jobs = []
    for c in CORE:
        add(jobs, 'B2_ff', c, ['ff_feedback'])
    for c in LOADS:
        add(jobs, 'B2_ablacao', c, ['mpc_qp_v5', 'mpc_qp_estocastico_3cen'],
            variant='load_only', params=dict(information_policy=POLICY, mpc_foresight_grid=False))
        add(jobs, 'B2_ablacao', c, ['mpc_qp_v5', 'mpc_qp_estocastico_3cen'],
            variant='no_preview',
            params=dict(information_policy=POLICY, mpc_foresight_grid=False, mpc_foresight_load=False))
        add(jobs, 'B2_ablacao', c, ['mpc_qp_v5'], variant='horizon1',
            params=dict(information_policy=POLICY, Np_mpc=1, Nc_mpc=1))

    for wdu in [5, 50, 200, 500]:
        for du in [120, 200, 400]:
            for c in ['carga_faixas', 'nvml_llama2_stress', 'perda_fonte']:
                add(jobs, 'B3_miope', c, ['miope_qp'],
                    params=dict(w_mpc_delta_u=wdu, dPBESS_ref_max=du, dPBESS_ref_max_evento=du,
                                common_slew=True, information_policy=POLICY),
                    w_du=wdu, dU=du)
    for label, params in [
        ('recharge_cap_50', dict(heur_P_carga_max=50)),
        ('soc_band_2pct', dict(heur_banda_SOC=2.0)),
        ('slew_supervised', dict(common_slew=True)),
    ]:
        for c in ['carga_faixas', 'nvml_llama2_stress', 'perda_fonte']:
            add(jobs, 'B3_heur', c, ['heuristico'], params=dict(information_policy=POLICY, **params),
                variant=label)

    patterns = [
        ('three_short', [{'t0': 420, 't1': 440}, {'t0': 500, 't1': 520}, {'t0': 620, 't1': 640}]),
        ('two_medium', [{'t0': 380, 't1': 410}, {'t0': 560, 't1': 590}]),
        ('dense_prep', [{'t0': 450, 't1': 470}, {'t0': 480, 't1': 500}, {'t0': 510, 't1': 530},
                        {'t0': 540, 't1': 560}]),
        ('late_burst', [{'t0': 700, 't1': 730}, {'t0': 800, 't1': 820}]),
    ]
    for name, pulses in patterns:
        add(jobs, 'B4_alarmes', 'perda_fonte', CTRL6, event_mode='false_alarm_repeated',
            pulses=pulses, pattern=name)

    rng = np.random.default_rng(SEED)
    delays = [int(np.rint(np.clip(abs(rng.normal(0, 6)), 0, 20))) for _ in range(40)]
    for i, delay in enumerate(delays, 1):
        add(jobs, 'B4_deteccao', 'perda_fonte', ['mpc_qp_v5'],
            event_mode='detection_delay', delay=delay, trial=i,
            params=dict(information_policy=POLICY))

    nom = dict(source_tracking=3000, rampa=300, soc=1200, soc_terminal=12000, uso_bess=20)
    for field, value in nom.items():
        for fac in [0.1, 10]:
            for c in ['perda_fonte', 'carga_faixas']:
                add(jobs, 'B5_pesos', c, ['mpc_qp_v5'],
                    params={f'w_mpc_{field}': value * fac, 'information_policy': POLICY},
                    weight=field, factor=fac)
    for Np, Nc in [(12, 4), (30, 8), (60, 15)]:
        for c in ['carga_faixas', 'perda_fonte']:
            add(jobs, 'B5_horizonte', c, ['mpc_qp_v5'],
                params=dict(Np_mpc=Np, Nc_mpc=Nc, information_policy=POLICY), Np=Np, Nc=Nc)

    for delay in [10, 30, 60]:
        add(jobs, 'B6_gerador', 'perda_fonte', CTRL5,
            params=dict(Pgen_kW=400, Pgen_delay_s=delay, information_policy=POLICY), delay=delay)
    add(jobs, 'B6_gerador_longo', 'falha_critica', ['heuristico', 'mpc_qp_v5'],
        params=dict(Tf=9600, Pgen_kW=400, Pgen_delay_s=30, information_policy=POLICY))
    add(jobs, 'B6_aging_qp', 'perda_fonte', ['mpc_qp_v5'],
        params=dict(w_mpc_uso_bess=200, information_policy=POLICY), variant='uso_bess_x10')
    for c in ['carga_faixas', 'perda_fonte']:
        add(jobs, 'B6_dinamica', c, CTRL6,
            params=dict(converter_dP_max=80, information_policy=POLICY))
    for i in range(1, 21):
        for c in ['perda_fonte', 'nvml_llama2_stress']:
            add(jobs, 'B6_ruido', c, ['mpc_qp_v5'],
                params=dict(sigma_L=5.0, sigma_SOC=0.2, noise_seed=SEED + i,
                            information_policy=POLICY), trial=i)
    add(jobs, 'B6_segundo_evento', 'perda_fonte', CTRL6,
        extra_outage=[900, 1050],
        params=dict(SOC_initial=30, information_policy=POLICY))

    out = HERE / 'jobs_blocos_2_6.json'
    assert not out.exists(), out
    out.write_text(json.dumps(jobs, indent=2), encoding='utf8')
    counts = {}
    for j in jobs:
        counts[j['group']] = counts.get(j['group'], 0) + 1
    print({'total': len(jobs), 'groups': counts})


if __name__ == '__main__':
    main()
