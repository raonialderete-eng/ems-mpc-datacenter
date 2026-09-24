#include "ems_clock.h"

#if defined(_WIN32) && !defined(__MINGW32__) && !defined(__MINGW64__)
#include <windows.h>

double ems_now_s(void)
{
    static double inv_freq;
    LARGE_INTEGER t;
    if (inv_freq == 0.0) {
        LARGE_INTEGER f;
        QueryPerformanceFrequency(&f);
        inv_freq = 1.0 / (double)f.QuadPart;
    }
    QueryPerformanceCounter(&t);
    return (double)t.QuadPart * inv_freq;
}

#else
#include <time.h>

double ems_now_s(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + 1e-9 * (double)ts.tv_nsec;
}

#endif
