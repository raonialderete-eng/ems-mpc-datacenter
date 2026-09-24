#ifndef QP_SHA256_H
#define QP_SHA256_H

/* SHA-256 of the mathematical QP: n,m,P,q,A,l,u. No k, filename, x. */
void qp_id_sha256(const double *P, const double *q, const double *A,
                  const double *l, const double *u, int n, int m,
                  char out_hex[65]);

#endif
