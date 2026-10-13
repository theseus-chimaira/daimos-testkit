/* C99 host/native inline-token codec acceptance and malformed input. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "d6codec-codec-v068.h"
#define N 10000U
static void check(int ok, const char *msg)
{
    if (!ok) { fprintf(stderr, "v068 FAIL: %s\n", msg); exit(1); }
}
int main(void)
{
    uint64_t *src = calloc(N, sizeof(*src));
    uint64_t *dst = calloc(N + 1U, sizeof(*dst));
    uint64_t *packed = NULL;
    uint64_t seed = UINT64_C(012345671234);
    size_t n = 0, i;
    uint64_t odd[] = { UINT64_C(0200000000000),
        UINT64_C(012345023456), UINT64_C(0402001) };
    uint64_t expect[] = { UINT64_C(012345023456),
        UINT64_C(023456023456), UINT64_C(023456023456) };
    check(src && dst, "allocation");
    check(d6codec_decode_v068(odd, 3, dst, 3) == 0, "odd halfword");
    check(memcmp(dst, expect, sizeof(expect)) == 0, "odd halfword value");
    check(d6codec_decode_v068(odd, 2, dst, 3) != 0, "truncated");
    check(d6codec_decode_v068(odd, 3, dst, 2) != 0, "wrong output");
    check(d6codec_decode_v068(odd, 4, dst, 3) != 0, "trailing input");
    for (i = 0; i < N; ++i) {
        seed = (seed * UINT64_C(1103515245) + 12345U) &
            UINT64_C(0777777777777);
        src[i] = i % 37U < 19U ? 0 : (i % 17U < 9U ?
            src[i > 64U ? i - 64U : 0U] : seed);
    }
    check(d6codec_encode_v068(src, N, &packed, &n) == 0, "encode");
    check(n > 0 && n < N, "compression");
    dst[N] = UINT64_C(012345670123);
    check(d6codec_decode_v068(packed, n, dst, N) == 0, "roundtrip");
    check(memcmp(src, dst, N * sizeof(*src)) == 0, "contents");
    check(dst[N] == UINT64_C(012345670123), "output guard");
    for (i = 0; i < n && i < 1000U; ++i) {
        uint64_t saved = packed[i];
        packed[i] |= UINT64_C(1) << 37U;
        check(d6codec_decode_v068(packed, n, dst, N) != 0,
            "reject overwide compressed word");
        packed[i] = saved;
    }
    check(d6codec_decode_v068(packed, n - 1, dst, N) != 0,
        "reject truncated payload");
    free(packed); free(dst); free(src);
    puts("v068 PASS native C codec and malformed streams");
    return 0;
}
