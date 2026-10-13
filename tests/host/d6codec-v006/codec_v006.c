/* Research-only compact match descriptors, C99. */
#include "codec_v006.h"
extern int d6v006_source_encode(const uint64_t *, size_t, int, uint64_t **, size_t *);
#include <stdlib.h>
#include <string.h>
#define M36 UINT64_C(0777777777777)
#define M18 UINT64_C(0777777)
/* 18-bit: 2-bit kind, 7-bit word length, 9-bit distance. */
static uint64_t pack(unsigned kind, size_t len, size_t dist)
{
 return ((uint64_t)kind << 16) | ((uint64_t)len << 9) | dist;
}
static uint64_t half(const uint64_t *out, size_t h)
{
 return (out[h / 2] >> ((h & 1U) ? 0 : 18)) & M18;
}
static void put_half(uint64_t *out, size_t h, uint64_t v)
{
 if (h & 1U) out[h / 2] = (out[h / 2] & ~M18) | v;
 else out[h / 2] = (out[h / 2] & M18) | (v << 18);
}
int d6v006_decode(const uint64_t *in, size_t ni, uint64_t *out, size_t no)
{
 size_t ip = 0, op = 0, j, di, li, count, nm;
 if ((!in && ni) || (!out && no)) return -1;
 while (op < no) {
  uint64_t ctrl, flags;
  if (ip >= ni) return -1;
  ctrl = in[ip++];
  if (ctrl & ~M36) return -1;
  count = (size_t)(ctrl >> 30);
  if (count == 0 || count > 30) return -1;
  flags = ctrl & ((UINT64_C(1) << 30) - 1);
  if (flags & ((UINT64_C(1) << (30 - count)) - 1)) return -1;
  nm = 0;
  for (j = 0; j < count; j++) if (flags & (UINT64_C(1) << (29 - j))) nm++;
  if ((nm + 1) / 2 > ni - ip) return -1;
  di = ip;
  li = ip + (nm + 1) / 2;
  for (j = 0; j < count; j++) {
   uint64_t token;
   size_t len, dist, z;
   unsigned kind;
   if (!(flags & (UINT64_C(1) << (29 - j)))) {
    if (li >= ni || op >= no) return -1;
    token = in[li++];
    if (token & ~M36) return -1;
    out[op++] = token;
    continue;
   }
   z = di++;
   token = in[ip + (z - ip) / 2];
   token = ((z - ip) & 1U) ? (token & M18) : (token >> 18);
   kind = (unsigned)(token >> 16);
   len = (size_t)((token >> 9) & 127U);
   dist = (size_t)(token & 511U);
   if (!len || len > no - op) return -1;
   if (kind == 0) {
    if (!dist || dist > op) return -1;
    for (z = 0; z < len; z++) { out[op] = out[op - dist]; op++; }
   } else if (kind == 1) {
    if (dist) return -1;
    for (z = 0; z < len; z++) out[op++] = 0;
   } else if (kind == 2) {
    size_t h = op * 2;
    if (!dist || dist > h) return -1;
    if (!(dist & 1U)) {
     for (z = 0; z < len; z++) out[op + z] = out[op + z - dist / 2];
    } else {
     for (z = 0; z < len; z++) out[op + z] = 0;
     for (z = 0; z < 2 * len; z++) put_half(out, h + z, half(out, h + z - dist));
    }
    op += len;
   } else return -1;
  }
  ip = li;
 }
 return ip == ni ? 0 : -1;
}
int d6v006_encode(const uint64_t *in, size_t n, uint64_t **outp, size_t *outn)
{
 uint64_t *old = NULL, *out = NULL;
 size_t oldn, cap, ip = 0, op = 0, remaining = 0, pos = 0;
 uint64_t flags = 0;
 if (!outp || !outn || (n && !in) || n > (SIZE_MAX - 64) / 4) return -1;
 if (d6v006_source_encode(in, n, 1, &old, &oldn)) return -1;
 cap = 4 * n + 64;
 out = (uint64_t *)malloc(cap * sizeof(*out));
 if (!out) { free(old); return -1; }
 while (pos < n) {
  uint64_t matches[30], literals[30], control = 0;
  size_t nm = 0, nl = 0, count = 0, start = op, i;
  while (count < 30 && pos < n) {
   uint64_t t; size_t len, dist, piece; unsigned kind;
   if (!remaining) { if (ip >= oldn) goto fail; flags = old[ip++]; remaining = 36; }
   if (ip >= oldn) goto fail;
   t = old[ip++];
   if (!(flags & (UINT64_C(1) << 35))) { literals[nl++] = t; pos++; count++; }
   else {
    kind = (unsigned)(t >> 34);
    len = (size_t)((t >> 18) & 65535U);
    dist = (size_t)(t & 262143U);
    if (kind > 2 || (kind != 1 && dist > 511)) goto fail;
    if (kind == 2) { if (len & 1U) goto fail; len /= 2; }
    if (!len) goto fail;
    piece = len > 127 ? 127 : len;
    matches[nm++] = pack(kind, piece, dist);
    control |= UINT64_C(1) << (29 - count);
    pos += piece;
    count++;
    /* Keep remainder as a synthetic descriptor for following tokens. */
    if (piece < len) {
     size_t rest = len - piece;
     /* The source stream cannot be rewound into its control bitmap.
        Reject this uncommon case until streaming splitting is implemented. */
     (void)rest;
     goto fail;
    }
   }
   flags <<= 1; remaining--;
  }
  out[op++] = ((uint64_t)count << 30) | control;
  for (i = 0; i < nm; i += 2)
   out[op++] = (matches[i] << 18) | ((i + 1 < nm) ? matches[i + 1] : 0);
  for (i = 0; i < nl; i++) out[op++] = literals[i];
  if (op > cap || op <= start) goto fail;
 }
 free(old); *outp = out; *outn = op; return 0;
fail:
 free(old); free(out); return -1;
}
