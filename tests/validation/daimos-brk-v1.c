#include "u.h"

extern void *malloc(unsigned int);
extern void free(void *);
extern void *sbrk(long);
extern int brk(void *);

static void
putstr(const char *text)
{
        while (*text != '\0') {
                (void)dsys_writechar(1, *text);
                ++text;
        }
}

int
main(void)
{
        kword_t before;
        kword_t grown;
        kword_t after;
        unsigned char *p;
        unsigned int i;

        before = dsys_brk(0UL);
        if (before == (kword_t)-1L)
                return 10;

        /* 9000 C characters require enough words to cross the initial
         * allocation boundary in the normal DAIMOS user process layout. */
        p = (unsigned char *)malloc(9000U);
        if (p == 0)
                return 11;
        for (i = 0U; i < 9000U; ++i)
                p[i] = (unsigned char)(i & 0377U);
        for (i = 0U; i < 9000U; ++i)
                if (p[i] != (unsigned char)(i & 0377U))
                        return 12;

        grown = dsys_brk(0UL);
        if (grown <= before)
                return 13;

        free(p);
        if (brk((void *)(unsigned long)before) != 0)
                return 14;
        after = dsys_brk(0UL);
        if (after != before)
                return 15;

        if (sbrk(64L) == (void *)-1L)
                return 16;
        if (dsys_brk(0UL) <= before)
                return 17;
        if (brk((void *)(unsigned long)before) != 0)
                return 18;

        putstr("BRK-PASS\n");
        return 0;
}
