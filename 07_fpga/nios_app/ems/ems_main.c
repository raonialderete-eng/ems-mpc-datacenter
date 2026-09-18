/*
 * Firmware EMS — demo standalone ou HIL UART (SW[0]).
 * Fontes do solver: 07_fpga/c_golden
 */
#ifdef PC_GOLDEN
/* Use 07_fpga/c_golden/ems_golden_main.c no PC. */
int main(void) { return 0; }
#else

#include "system.h"
#include "alt_types.h"
#include "altera_avalon_pio_regs.h"
#include "altera_avalon_uart_regs.h"
#include <string.h>

#include "ems_param.h"
#include "planta_bess.h"
#include "controle_heuristico.h"
#include "controle_mpc_fpga.h"
#include "gera_cenario.h"
#include "ems_protocol.h"

static void delay_demo(void)
{
    volatile alt_u32 d;
    for (d = 0; d < 250000u; d++) {
    }
}

static unsigned hex7(int d)
{
    switch (d % 10) {
    case 0: return 0x40;
    case 1: return 0x79;
    case 2: return 0x24;
    case 3: return 0x30;
    case 4: return 0x19;
    case 5: return 0x12;
    case 6: return 0x02;
    case 7: return 0x78;
    case 8: return 0x00;
    case 9: return 0x10;
    default: return 0x7F;
    }
}

static void mostra_io(int grid, int fb, int evt, int soc, double pnao, double uref)
{
    alt_u32 led = 0;
    alt_u32 hex;
    if (grid) led |= 1u;
    if (fb)   led |= 2u;
    if (evt)  led |= 4u;
    if (pnao > 1.0) led |= 8u;
    IOWR_ALTERA_AVALON_PIO_DATA(PIO_LED_BASE, led);
    hex = (hex7(soc / 10) << 7) | hex7(soc % 10);
    IOWR_ALTERA_AVALON_PIO_DATA(PIO_HEX_BASE, hex);
    (void)uref;
}

static void uart_putc(char c)
{
    while (!(IORD_ALTERA_AVALON_UART_STATUS(UART_BASE) & ALTERA_AVALON_UART_STATUS_TRDY_MSK))
        ;
    IOWR_ALTERA_AVALON_UART_TXDATA(UART_BASE, c);
}

static void uart_puts(const char *s)
{
    while (*s)
        uart_putc(*s++);
}

static int uart_getc_nb(void)
{
    if (IORD_ALTERA_AVALON_UART_STATUS(UART_BASE) & ALTERA_AVALON_UART_STATUS_RRDY_MSK)
        return (int)IORD_ALTERA_AVALON_UART_RXDATA(UART_BASE);
    return -1;
}

static void utoa_dec(unsigned long v, char *s)
{
    char tmp[20];
    int n = 0, i;
    if (v == 0) {
        s[0] = '0';
        s[1] = 0;
        return;
    }
    while (v > 0 && n < 20) {
        tmp[n++] = (char)('0' + (v % 10u));
        v /= 10u;
    }
    for (i = 0; i < n; ++i)
        s[i] = tmp[n - 1 - i];
    s[n] = 0;
}

static void fmt_f8(double x, char *s)
{
    unsigned long ip, frac;
    int n, neg = 0;
    if (x < 0.0) {
        neg = 1;
        x = -x;
    }
    ip = (unsigned long)x;
    frac = (unsigned long)((x - (double)ip) * 1e8 + 0.5);
    if (frac >= 100000000u) {
        ip += 1u;
        frac = 0;
    }
    n = 0;
    if (neg)
        s[n++] = '-';
    utoa_dec(ip, s + n);
    while (s[n])
        n++;
    s[n++] = '.';
    {
        char f[12];
        int k, pad;
        utoa_dec(frac, f);
        pad = 8 - (int)strlen(f);
        while (pad-- > 0)
            s[n++] = '0';
        k = 0;
        while (f[k])
            s[n++] = f[k++];
    }
    s[n] = 0;
}

static void hil_fmt_rsp(const HilRsp *rsp, char *out, int nmax)
{
    char f[32], t[20], a[12], b[12], c[12];
    int n = 0;
    fmt_f8(rsp->PBESS_ref, f);
    utoa_dec(rsp->t_us, t);
    utoa_dec((unsigned long)rsp->exitflag, a);
    utoa_dec((unsigned long)rsp->fallback, b);
    utoa_dec((unsigned long)rsp->evento, c);
    {
        const char *p = "RSP ";
        while (*p && n < nmax - 2)
            out[n++] = *p++;
        p = f;
        while (*p && n < nmax - 2)
            out[n++] = *p++;
        out[n++] = ' ';
        p = t;
        while (*p && n < nmax - 2)
            out[n++] = *p++;
        out[n++] = ' ';
        p = a;
        while (*p && n < nmax - 2)
            out[n++] = *p++;
        out[n++] = ' ';
        p = b;
        while (*p && n < nmax - 2)
            out[n++] = *p++;
        out[n++] = ' ';
        p = c;
        while (*p && n < nmax - 2)
            out[n++] = *p++;
        out[n++] = '\n';
        out[n] = 0;
    }
}

static int uart_gets(char *buf, int n)
{
    int i = 0, ch;
    while (i < n - 1) {
        if (!(IORD_ALTERA_AVALON_PIO_DATA(PIO_SW_BASE) & 0x1)) {
            buf[0] = 0;
            return -1;
        }
        ch = uart_getc_nb();
        if (ch < 0)
            continue;
        if (ch == '\n' || ch == '\r') {
            buf[i] = 0;
            return i;
        }
        buf[i++] = (char)ch;
    }
    buf[n - 1] = 0;
    return i;
}

static void modo_hil(EmsParam *param, int usa_mpc)
{
    char line[2048];
    char out[160];
    HilReq req;
    HilRsp rsp;
    (void)IORD_ALTERA_AVALON_UART_STATUS(UART_BASE);
    IOWR_ALTERA_AVALON_UART_CONTROL(UART_BASE, ALTERA_AVALON_UART_CONTROL_RTS_MSK);
    uart_puts("EMS HIL ready\n");
    mostra_io(1, 0, usa_mpc, 60, 0.0, 0.0);
    while (IORD_ALTERA_AVALON_PIO_DATA(PIO_SW_BASE) & 0x1) {
        usa_mpc = (IORD_ALTERA_AVALON_PIO_DATA(PIO_SW_BASE) & 0x4) != 0;
        if (uart_gets(line, sizeof(line)) <= 0)
            continue;
        if (ems_parse_req(line, &req) != 0) {
            uart_puts("ERR parse\n");
            continue;
        }
        if (!usa_mpc) {
            rsp.PBESS_ref = controle_heuristico(req.Pload[0], req.Pmax[0],
                                                req.grid[0], req.SOC, param);
            rsp.exitflag = 1;
            rsp.fallback = 0;
            rsp.evento = 0;
            rsp.t_us = 0;
        } else {
            MpcInfo inf;
            int g[EMS_NP];
            int i;
            for (i = 0; i < req.Np; ++i)
                g[i] = req.grid[i];
            inf = controle_mpc_fpga(0, req.SOC, req.PBESS, req.uref, req.Psrc_ant,
                                    req.Pload, req.Pmax, g, req.Np, param);
            rsp.PBESS_ref = inf.PBESS_ref;
            rsp.exitflag = inf.exitflag;
            rsp.fallback = inf.usou_fallback;
            rsp.evento = inf.modo_evento;
            rsp.t_us = (unsigned long)(inf.tempo_qp_s * 1e6);
        }
        hil_fmt_rsp(&rsp, out, sizeof(out));
        uart_puts(out);
        mostra_io(req.grid[0], rsp.fallback, usa_mpc, (int)req.SOC, 0.0, rsp.PBESS_ref);
    }
}

static void modo_demo(EmsParam *param, int usa_mpc, const char *cenario)
{
    enum { WIN = EMS_NP };
    double L[WIN], Px[WIN];
    int g[WIN];
    int N, k, i, nwin;
    double SOC, PBESS, uref, Psrc;
    if (strcmp(cenario, "carga_faixas") != 0 && strcmp(cenario, "perda_fonte") != 0 &&
        strcmp(cenario, "limite_fonte") != 0 && strcmp(cenario, "retorno_fonte") != 0)
        return;
    N = gera_n(param);
    SOC = param->SOC_ref;
    PBESS = 0.0;
    uref = 0.0;
    gera_amostra(cenario, param, 0, &L[0], &Px[0], &g[0]);
    Psrc = L[0];
    for (k = 0; k < N - 1; ++k) {
        double u;
        PlantaOut po;
        int fb = 0;
        int evt = 0;
        nwin = WIN;
        if (k + nwin > N)
            nwin = N - k;
        for (i = 0; i < nwin; ++i)
            gera_amostra(cenario, param, k + i, &L[i], &Px[i], &g[i]);
        if (!usa_mpc) {
            u = controle_heuristico_foresight(0, SOC, uref, L, Px, g, nwin, param);
        } else {
            MpcInfo inf;
            inf = controle_mpc_fpga(0, SOC, PBESS, uref, Psrc, L, Px, g, nwin, param);
            u = inf.PBESS_ref;
            fb = inf.usou_fallback;
            evt = inf.modo_evento;
        }
        po = planta_bess(SOC, PBESS, u, L[0], Px[0], g[0], param);
        mostra_io(g[0], fb, evt, (int)po.SOC_next, po.Pnao, u);
        SOC = po.SOC_next;
        PBESS = po.PBESS_next;
        Psrc = po.Psource;
        uref = u;
        delay_demo();
    }
}

int main(void)
{
    EmsParam param;
    alt_u32 sw;
    ems_param_fpga(&param);
    /* Sem alt_printf: JTAG UART trava o Nios se ninguem estiver lendo. */
    while (1) {
        sw = IORD_ALTERA_AVALON_PIO_DATA(PIO_SW_BASE);
        if (sw & 0x1)
            modo_hil(&param, (sw & 0x4) != 0);
        else
            modo_demo(&param, (sw & 0x4) != 0, (sw & 0x2) ? "perda_fonte" : "carga_faixas");
    }
    return 0;
}

#endif
