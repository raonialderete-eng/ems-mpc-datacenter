#include "gera_cenario.h"
#include <math.h>
#include <string.h>

int gera_n(const EmsParam *param)
{
    return (int)(param->Tf / param->Ts) + 1;
}

void gera_amostra(const char *tipo, const EmsParam *param, int i,
                  double *Pload, double *Psource_max, int *grid_status)
{
    double t = i * param->Ts;
    *Pload = param->Pload_base;
    *Psource_max = param->Psource_max_nominal;
    *grid_status = 1;

    if (strcmp(tipo, "carga_faixas") == 0) {
        if (t >= 0.0 && t < 200.0)
            *Pload = param->Pload_base;
        else if (t < 400.0)
            *Pload = param->Pload_media;
        else if (t < 650.0)
            *Pload = param->Pload_alta;
        else if (t < 850.0)
            *Pload = 700.0;
        else
            *Pload = param->Pload_base;
    } else if (strcmp(tipo, "limite_fonte") == 0) {
        *Pload = (t >= 200.0) ? param->Pload_alta : param->Pload_media;
    } else if (strcmp(tipo, "perda_fonte") == 0) {
        *Pload = param->Pload_media;
        if (t >= 500.0 && t < 650.0)
            *grid_status = 0;
        *Psource_max = param->Psource_max_nominal * (*grid_status);
    } else if (strcmp(tipo, "retorno_fonte") == 0) {
        *Pload = param->Pload_media;
        if (t >= 400.0 && t < 650.0)
            *grid_status = 0;
        *Psource_max = param->Psource_max_nominal * (*grid_status);
    }
}

int gera_cenario(const char *tipo, const EmsParam *param,
                 double *Pload, double *Psource_max, int *grid_status, int *N)
{
    int i;
    int n = gera_n(param);

    if (strcmp(tipo, "carga_faixas") != 0 && strcmp(tipo, "limite_fonte") != 0 &&
        strcmp(tipo, "perda_fonte") != 0 && strcmp(tipo, "retorno_fonte") != 0)
        return -1;

    *N = n;
    for (i = 0; i < n; ++i)
        gera_amostra(tipo, param, i, &Pload[i], &Psource_max[i], &grid_status[i]);
    return 0;
}
