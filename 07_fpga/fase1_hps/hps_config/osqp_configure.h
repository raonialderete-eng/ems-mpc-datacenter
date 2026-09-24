#ifndef OSQP_CONFIGURE_H
#define OSQP_CONFIGURE_H

/* Configuracao OSQP 1.0 para gcc da DE10-Standard (Linux ARM) e MinGW.
 * Sem CMake. Impressao desligada (UART). Sem codegen/derivadas. */

#ifdef _WIN32
#define IS_WINDOWS
#else
#define IS_LINUX
#endif

#define OSQP_ALGEBRA_BUILTIN
#define OSQP_ENABLE_PROFILING
#define OSQP_USE_LONG

#endif
