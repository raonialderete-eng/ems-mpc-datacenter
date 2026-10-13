#ifndef EMS_CLOCK_H
#define EMS_CLOCK_H

#ifdef __cplusplus
extern "C" {
#endif

/* CLOCK_MONOTONIC no POSIX; QueryPerformanceCounter no MSVC. Nunca zerar o QP. */
double ems_now_s(void);

#ifdef __cplusplus
}
#endif

#endif
