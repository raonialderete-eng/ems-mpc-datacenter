#include "ems_protocol.h"
#include <stdlib.h>
#include <string.h>
#ifndef __hal__
#include <stdio.h>
#endif

int ems_parse_req(const char *line, HilReq *req)
{
    const char *p;
    int i;
    memset(req, 0, sizeof(*req));
    if (strncmp(line, "REQ", 3) != 0)
        return -1;
    p = line + 3;
    req->k = (int)strtol(p, (char **)&p, 10);
    req->SOC = strtod(p, (char **)&p);
    req->PBESS = strtod(p, (char **)&p);
    req->uref = strtod(p, (char **)&p);
    req->Psrc_ant = strtod(p, (char **)&p);
    req->Np = (int)strtol(p, (char **)&p, 10);
    if (req->Np < 1 || req->Np > EMS_NP)
        return -3;
    for (i = 0; i < req->Np; ++i)
        req->Pload[i] = strtod(p, (char **)&p);
    for (i = 0; i < req->Np; ++i)
        req->Pmax[i] = strtod(p, (char **)&p);
    for (i = 0; i < req->Np; ++i)
        req->grid[i] = (int)strtol(p, (char **)&p, 10);
    return 0;
}

#ifndef __hal__
void ems_print_rsp(const HilRsp *rsp)
{
    printf("RSP %.8f %lu %d %d %d\n",
           rsp->PBESS_ref, rsp->t_us, rsp->exitflag, rsp->fallback, rsp->evento);
}

void ems_format_req(const HilReq *req, char *buf, int buflen)
{
    int n, i;
    n = snprintf(buf, buflen, "REQ %d %.8f %.8f %.8f %.8f %d",
                 req->k, req->SOC, req->PBESS, req->uref, req->Psrc_ant, req->Np);
    for (i = 0; i < req->Np && n < buflen - 16; ++i)
        n += snprintf(buf + n, buflen - n, " %.8f", req->Pload[i]);
    for (i = 0; i < req->Np && n < buflen - 16; ++i)
        n += snprintf(buf + n, buflen - n, " %.8f", req->Pmax[i]);
    for (i = 0; i < req->Np && n < buflen - 8; ++i)
        n += snprintf(buf + n, buflen - n, " %d", req->grid[i]);
    if (n < buflen - 2) {
        buf[n++] = '\n';
        buf[n] = '\0';
    }
}
#endif

