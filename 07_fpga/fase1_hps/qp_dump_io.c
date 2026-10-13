#include "qp_dump_io.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int expect_tag(FILE *fp, const char *tag)
{
    char buf[64];
    for (;;) {
        if (!fgets(buf, sizeof(buf), fp))
            return -1;
        {
            size_t n = strlen(buf);
            while (n && (buf[n - 1] == '\n' || buf[n - 1] == '\r' || buf[n - 1] == ' '))
                buf[--n] = 0;
            if (n == 0)
                continue;
            return strcmp(buf, tag) == 0 ? 0 : -1;
        }
    }
}

int qp_dump_load(const char *path, QpDump *d)
{
    FILE *fp;
    char line[256];
    int i, j;

    memset(d, 0, sizeof(*d));
    fp = fopen(path, "r");
    if (!fp)
        return -1;
    d->rho = 1.0;
    while (fgets(line, sizeof(line), fp)) {
        char key[32];
        double val;
        if (strncmp(line, "P", 1) == 0 && (line[1] == '\n' || line[1] == '\r' || line[1] == 0))
            break;
        if (sscanf(line, "%31s %lf", key, &val) != 2)
            continue;
        if (strcmp(key, "k") == 0) d->k = (int)val;
        else if (strcmp(key, "n") == 0) d->n = (int)val;
        else if (strcmp(key, "m") == 0) d->m = (int)val;
        else if (strcmp(key, "exit") == 0) d->ex = (int)val;
        else if (strcmp(key, "pri") == 0) d->pri = val;
        else if (strcmp(key, "n_iter") == 0) d->n_iter = (int)val;
        else if (strcmp(key, "rho") == 0) d->rho = val;
        else if (strcmp(key, "cost") == 0) d->cost = val;
    }
    if (d->n <= 0 || d->n > EMS_NVAR || d->m <= 0 || d->m > EMS_NCONS_MAX) {
        fclose(fp);
        return -1;
    }
    for (i = 0; i < d->n; ++i)
        for (j = 0; j < d->n; ++j)
            if (fscanf(fp, "%lf", &d->P[i * d->n + j]) != 1) {
                fclose(fp);
                return -1;
            }
    if (expect_tag(fp, "q") != 0) {
        fclose(fp);
        return -1;
    }
    for (i = 0; i < d->n; ++i)
        if (fscanf(fp, "%lf", &d->q[i]) != 1) {
            fclose(fp);
            return -1;
        }
    if (expect_tag(fp, "A") != 0) {
        fclose(fp);
        return -1;
    }
    for (i = 0; i < d->m; ++i)
        for (j = 0; j < d->n; ++j)
            if (fscanf(fp, "%lf", &d->A[i * d->n + j]) != 1) {
                fclose(fp);
                return -1;
            }
    if (expect_tag(fp, "l") != 0) {
        fclose(fp);
        return -1;
    }
    for (i = 0; i < d->m; ++i)
        if (fscanf(fp, "%lf", &d->l[i]) != 1) {
            fclose(fp);
            return -1;
        }
    if (expect_tag(fp, "u") != 0) {
        fclose(fp);
        return -1;
    }
    for (i = 0; i < d->m; ++i)
        if (fscanf(fp, "%lf", &d->u[i]) != 1) {
            fclose(fp);
            return -1;
        }
    if (expect_tag(fp, "x") != 0) {
        fclose(fp);
        return -1;
    }
    for (i = 0; i < d->n; ++i)
        if (fscanf(fp, "%lf", &d->x[i]) != 1) {
            fclose(fp);
            return -1;
        }
    fclose(fp);
    return 0;
}

unsigned long qp_dump_hash(const QpDump *d)
{
    unsigned long h = 5381ul;
    int i, nn = d->n * d->n + d->n + d->m * d->n + 2 * d->m;
    const double *blocks[5];
    int lens[5];
    int b, k;
    blocks[0] = d->P; lens[0] = d->n * d->n;
    blocks[1] = d->q; lens[1] = d->n;
    blocks[2] = d->A; lens[2] = d->m * d->n;
    blocks[3] = d->l; lens[3] = d->m;
    blocks[4] = d->u; lens[4] = d->m;
    (void)nn;
    for (b = 0; b < 5; ++b)
        for (k = 0; k < lens[b]; ++k) {
            unsigned char *p = (unsigned char *)&blocks[b][k];
            size_t t;
            for (t = 0; t < sizeof(double); ++t)
                h = ((h << 5) + h) + p[t];
        }
    h = ((h << 5) + h) + (unsigned long)d->n;
    h = ((h << 5) + h) + (unsigned long)d->m;
    h = ((h << 5) + h) + (unsigned long)d->k;
    return h;
}
