/* GCC C89 client of the KCC-built production DAIMOS libc archive.
 * The real dsys_brk monitor veneer backs the heap; no GCC allocator. */
#include <p10stdio-daimos-v1.h>

extern void *malloc(unsigned int);
extern void free(void *);
extern void *calloc(unsigned int, unsigned int);
extern void *realloc(void *, unsigned int);
extern unsigned long dsys_brk(unsigned long);

static int
check_words_v1828(const unsigned long *p, unsigned int n, unsigned long v)
{
    unsigned int i;
    for (i = 0U; i < n; ++i)
        if (p[i] != v + (unsigned long)i)
            return 0;
    return 1;
}

int
main(void)
{
    unsigned long before, after;
    unsigned long *a, *b, *c, *d;
    unsigned int i;

    before = dsys_brk(0UL);
    if (before == (unsigned long)-1L)
        return 11;
    /* Reject oversized and overflowing requests without growing BRK. */
    if (malloc(~0U) != (void *)0 || dsys_brk(0UL) != before)
        return 20;
    if (calloc(~0U, 2U) != (void *)0 || dsys_brk(0UL) != before)
        return 21;
    /* The address-space bound must reject even a nonoverflowing size. */
    if (malloc(010000000U) != (void *)0 || dsys_brk(0UL) != before)
        return 23;
    a = (unsigned long *)malloc(12U * sizeof(unsigned long));
    if (a == (unsigned long *)0)
        return 12;
    after = dsys_brk(0UL);
    if (after <= before)
        return 13;
    for (i = 0U; i < 12U; ++i)
        a[i] = 01000UL + (unsigned long)i;
    b = (unsigned long *)malloc(7U * sizeof(unsigned long));
    if (b == (unsigned long *)0)
        return 14;
    for (i = 0U; i < 7U; ++i)
        b[i] = 02000UL + (unsigned long)i;
    /* A failed resize must preserve the original allocation and BRK. */
    after = dsys_brk(0UL);
    if (realloc(a, ~0U) != (void *)0 ||
        dsys_brk(0UL) != after ||
        !check_words_v1828(a, 12U, 01000UL))
        return 22;
    if (realloc(a, 010000000U) != (void *)0 ||
        dsys_brk(0UL) != after ||
        !check_words_v1828(a, 12U, 01000UL) ||
        !check_words_v1828(b, 7U, 02000UL))
        return 24;
    c = (unsigned long *)realloc(a, 24U * sizeof(unsigned long));
    if (c == (unsigned long *)0 ||
        !check_words_v1828(c, 12U, 01000UL) ||
        !check_words_v1828(b, 7U, 02000UL))
        return 15;
    free(b);
    free(c);
    d = (unsigned long *)calloc(9U, sizeof(unsigned long));
    if (d == (unsigned long *)0)
        return 16;
    for (i = 0U; i < 9U; ++i)
        if (d[i] != 0UL)
            return 17;
    free(d);
    a = (unsigned long *)malloc(3U * sizeof(unsigned long));
    if (a == (unsigned long *)0)
        return 18;
    free(a);
    if (printf("GCC-HEAP-V1828-PASS\n") < 0)
        return 19;
    return 0;
}
