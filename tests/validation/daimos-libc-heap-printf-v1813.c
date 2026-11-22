/* Exercise actual KCC DAIMOS libc with real BRK and WRITECHAR veneers. */
#include "u.h"
extern void *malloc(unsigned int);
extern void *calloc(unsigned int, unsigned int);
extern void *realloc(void *, unsigned int);
extern void free(void *);
extern int printf(char *, ...);

int main(void)
{
    unsigned char *a, *b, *c;
    unsigned int i;
    kword_t initial = dsys_brk(0UL);
    if (initial == (kword_t)-1L) return 10;
    a = (unsigned char *)malloc(1024U);
    b = (unsigned char *)calloc(256U, 4U);
    if (!a || !b) return 11;
    for (i = 0U; i < 1024U; ++i) {
        a[i] = (unsigned char)(i & 0377U);
        if (b[i] != 0U) return 12;
    }
    c = (unsigned char *)realloc(a, 2048U);
    if (!c) return 13;
    for (i = 0U; i < 1024U; ++i)
        if (c[i] != (unsigned char)(i & 0377U)) return 14;
    free(b);
    free(c);
    if (printf("LIBC-HEAP-PRINTF-PASS %d %s\n", 1813, "OK") != 30)
        return 15;
    return 0;
}
