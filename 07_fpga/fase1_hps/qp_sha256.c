#include "qp_sha256.h"
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static uint32_t rotr(uint32_t x, int n)
{
    return (x >> n) | (x << (32 - n));
}

static void sha256_transform(uint32_t s[8], const unsigned char blk[64])
{
    static const uint32_t K[64] = {
        0x428a2f98u, 0x71374491u, 0xb5c0fbcfu, 0xe9b5dba5u, 0x3956c25bu, 0x59f111f1u,
        0x923f82a4u, 0xab1c5ed5u, 0xd807aa98u, 0x12835b01u, 0x243185beu, 0x550c7dc3u,
        0x72be5d74u, 0x80deb1feu, 0x9bdc06a7u, 0xc19bf174u, 0xe49b69c1u, 0xefbe4786u,
        0x0fc19dc6u, 0x240ca1ccu, 0x2de92c6fu, 0x4a7484aau, 0x5cb0a9dcu, 0x76f988dau,
        0x983e5152u, 0xa831c66du, 0xb00327c8u, 0xbf597fc7u, 0xc6e00bf3u, 0xd5a79147u,
        0x06ca6351u, 0x14292967u, 0x27b70a85u, 0x2e1b2138u, 0x4d2c6dfcu, 0x53380d13u,
        0x650a7354u, 0x766a0abbu, 0x81c2c92eu, 0x92722c85u, 0xa2bfe8a1u, 0xa81a664bu,
        0xc24b8b70u, 0xc76c51a3u, 0xd192e819u, 0xd6990624u, 0xf40e3585u, 0x106aa070u,
        0x19a4c116u, 0x1e376c08u, 0x2748774cu, 0x34b0bcb5u, 0x391c0cb3u, 0x4ed8aa4au,
        0x5b9cca4fu, 0x682e6ff3u, 0x748f82eeu, 0x78a5636fu, 0x84c87814u, 0x8cc70208u,
        0x90befffau, 0xa4506cebu, 0xbef9a3f7u, 0xc67178f2u
    };
    uint32_t w[64], a, b, c, d, e, f, g, h;
    int i;
    for (i = 0; i < 16; ++i)
        w[i] = ((uint32_t)blk[4 * i] << 24) | ((uint32_t)blk[4 * i + 1] << 16) |
               ((uint32_t)blk[4 * i + 2] << 8) | (uint32_t)blk[4 * i + 3];
    for (i = 16; i < 64; ++i) {
        uint32_t s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
        uint32_t s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
        w[i] = w[i - 16] + s0 + w[i - 7] + s1;
    }
    a = s[0]; b = s[1]; c = s[2]; d = s[3];
    e = s[4]; f = s[5]; g = s[6]; h = s[7];
    for (i = 0; i < 64; ++i) {
        uint32_t S1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
        uint32_t ch = (e & f) ^ ((~e) & g);
        uint32_t t1 = h + S1 + ch + K[i] + w[i];
        uint32_t S0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
        uint32_t maj = (a & b) ^ (a & c) ^ (b & c);
        uint32_t t2 = S0 + maj;
        h = g; g = f; f = e; e = d + t1; d = c; c = b; b = a; a = t1 + t2;
    }
    s[0] += a; s[1] += b; s[2] += c; s[3] += d;
    s[4] += e; s[5] += f; s[6] += g; s[7] += h;
}

static void sha256_bytes(const unsigned char *data, size_t len, unsigned char out[32])
{
    uint32_t s[8] = {
        0x6a09e667u, 0xbb67ae85u, 0x3c6ef372u, 0xa54ff53au,
        0x510e527fu, 0x9b05688cu, 0x1f83d9abu, 0x5be0cd19u
    };
    unsigned char blk[64];
    size_t i, n = len;
    const unsigned char *p = data;
    uint64_t bits = (uint64_t)len * 8ull;
    while (n >= 64) {
        sha256_transform(s, p);
        p += 64;
        n -= 64;
    }
    memset(blk, 0, 64);
    memcpy(blk, p, n);
    blk[n] = 0x80;
    if (n >= 56) {
        sha256_transform(s, blk);
        memset(blk, 0, 64);
    }
    for (i = 0; i < 8; ++i)
        blk[63 - i] = (unsigned char)(bits >> (8 * i));
    sha256_transform(s, blk);
    for (i = 0; i < 8; ++i) {
        out[4 * i] = (unsigned char)(s[i] >> 24);
        out[4 * i + 1] = (unsigned char)(s[i] >> 16);
        out[4 * i + 2] = (unsigned char)(s[i] >> 8);
        out[4 * i + 3] = (unsigned char)s[i];
    }
}

static void put_le32(unsigned char *p, int v)
{
    uint32_t u = (uint32_t)v;
    p[0] = (unsigned char)u;
    p[1] = (unsigned char)(u >> 8);
    p[2] = (unsigned char)(u >> 16);
    p[3] = (unsigned char)(u >> 24);
}

void qp_id_sha256(const double *P, const double *q, const double *A,
                  const double *l, const double *u, int n, int m,
                  char out_hex[65])
{
    size_t nd = (size_t)n * (size_t)n + (size_t)n + (size_t)m * (size_t)n + 2u * (size_t)m;
    size_t bytes = 8 + nd * sizeof(double);
    unsigned char *buf = (unsigned char *)malloc(bytes);
    unsigned char digest[32];
    size_t off = 0;
    int i;
    static const char *hex = "0123456789abcdef";
    if (!buf) {
        out_hex[0] = 0;
        return;
    }
    put_le32(buf + off, n); off += 4;
    put_le32(buf + off, m); off += 4;
    memcpy(buf + off, P, (size_t)n * (size_t)n * sizeof(double));
    off += (size_t)n * (size_t)n * sizeof(double);
    memcpy(buf + off, q, (size_t)n * sizeof(double));
    off += (size_t)n * sizeof(double);
    memcpy(buf + off, A, (size_t)m * (size_t)n * sizeof(double));
    off += (size_t)m * (size_t)n * sizeof(double);
    memcpy(buf + off, l, (size_t)m * sizeof(double));
    off += (size_t)m * sizeof(double);
    memcpy(buf + off, u, (size_t)m * sizeof(double));
    sha256_bytes(buf, bytes, digest);
    free(buf);
    for (i = 0; i < 32; ++i) {
        out_hex[2 * i] = hex[digest[i] >> 4];
        out_hex[2 * i + 1] = hex[digest[i] & 0xf];
    }
    out_hex[64] = 0;
}
