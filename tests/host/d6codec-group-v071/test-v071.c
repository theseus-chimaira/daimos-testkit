/* Native host C99 reference validation, independent token fixtures. */
#include <stdint.h>
#include <stdio.h>
#include "d6codec-group-v071.h"
#define WORD_MASK UINT64_C(0777777777777)
#define HALF UINT64_C(0777777)
#define DESC(kind,len,dist) (((uint64_t)(kind)<<16)|((uint64_t)(len)<<9)|(dist))
#define CTRL(count,bits) (((uint64_t)(count)<<30)|(bits))
static int check(const uint64_t *stream, size_t sn,
                 const uint64_t *expected, size_t en, int valid)
{
    uint64_t dest[32] = {0};
    size_t i;
    int rc = d6codec_group_v071_decode(stream, sn, dest, en);
    if ((rc == 0) != valid) return 1;
    if (!valid) return 0;
    for (i = 0; i < en; ++i)
        if (dest[i] != expected[i]) return 1;
    return 0;
}
int main(void)
{
    const uint64_t a = UINT64_C(012345670123);
    const uint64_t repeated = ((a & HALF) << 18) | (a & HALF);
    const uint64_t basic[] = {CTRL(2,UINT64_C(02000000000)),
        DESC(2,2,1)<<18, a};
    const uint64_t basic_result[] = {a,repeated,repeated};
    const uint64_t zero[] = {CTRL(1,UINT64_C(04000000000)),
        DESC(1,3,0)<<18};
    const uint64_t zero_result[] = {0,0,0};
    const uint64_t bad_kind[] = {CTRL(1,UINT64_C(04000000000)),
        DESC(3,1,1)<<18};
    const uint64_t truncated[] = {CTRL(1,0)};
    const uint64_t trailing[] = {CTRL(1,0),a,CTRL(1,0),a};
    const uint64_t word_copy[] = {CTRL(2,UINT64_C(02000000000)),
        DESC(0,2,1)<<18,a};
    const uint64_t word_result[] = {a,a,a};
    int errors = 0;
    errors += check(basic,3,basic_result,3,1);
    errors += check(zero,2,zero_result,3,1);
    errors += check(word_copy,3,word_result,3,1);
    errors += check(bad_kind,2,basic_result,1,0);
    errors += check(truncated,1,basic_result,1,0);
    errors += check(trailing,4,basic_result,1,0);
    if (errors) fprintf(stderr,"v071: %d failures\n",errors);
    else puts("PASS d6codec-group-v071 host C99 six cases");
    return errors ? 1 : 0;
}
