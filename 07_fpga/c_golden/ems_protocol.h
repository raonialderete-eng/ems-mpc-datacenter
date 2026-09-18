#ifndef EMS_PROTOCOL_H
#define EMS_PROTOCOL_H

#include "ems_types.h"

typedef struct {
    int k;
    double SOC;
    double PBESS;
    double uref;
    double Psrc_ant;
    int Np;
    double Pload[EMS_NP];
    double Pmax[EMS_NP];
    int grid[EMS_NP];
} HilReq;

typedef struct {
    double PBESS_ref;
    unsigned long t_us;
    int exitflag;
    int fallback;
    int evento;
} HilRsp;

int ems_parse_req(const char *line, HilReq *req);
void ems_print_rsp(const HilRsp *rsp);
void ems_format_req(const HilReq *req, char *buf, int buflen);

#endif
