#include "planta_bess.h"

static double dmin(double a, double b) { return a < b ? a : b; }
static double dmax(double a, double b) { return a > b ? a : b; }

PlantaOut planta_bess(double SOC, double PBESS, double PBESS_ref,
                      double Pload, double Psource_max, int grid_status,
                      const EmsParam *param)
{
    PlantaOut o;
    double delta_SOC;

    PBESS_ref = dmin(PBESS_ref, param->PBESS_max);
    PBESS_ref = dmax(PBESS_ref, param->PBESS_min);

    o.PBESS_next = param->ab * PBESS + param->bb * PBESS_ref;
    o.PBESS_next = dmin(o.PBESS_next, param->PBESS_max);
    o.PBESS_next = dmax(o.PBESS_next, param->PBESS_min);

    if (SOC <= param->SOC_min && o.PBESS_next > 0.0)
        o.PBESS_next = 0.0;
    if (SOC >= param->SOC_max && o.PBESS_next < 0.0)
        o.PBESS_next = 0.0;

    if (grid_status == 1)
        o.Psource = Pload - o.PBESS_next;
    else
        o.Psource = 0.0;

    if (o.Psource > Psource_max)
        o.Psource = Psource_max;
    if (o.Psource < 0.0)
        o.Psource = 0.0;

    o.Pnao = Pload - o.Psource - o.PBESS_next;
    if (o.Pnao < 0.0)
        o.Pnao = 0.0;

    if (o.PBESS_next >= 0.0)
        delta_SOC = (o.PBESS_next * param->Ts / 3600.0) /
                    (param->Ebat * param->eta_descarga) * 100.0;
    else
        delta_SOC = (o.PBESS_next * param->Ts / 3600.0) *
                    param->eta_carga / param->Ebat * 100.0;

    o.SOC_next = SOC - delta_SOC;
    o.SOC_next = dmin(o.SOC_next, param->SOC_max);
    o.SOC_next = dmax(o.SOC_next, param->SOC_min);
    return o;
}
