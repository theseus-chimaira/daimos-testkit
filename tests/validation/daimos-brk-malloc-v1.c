#include "u.h"

extern void *malloc(unsigned int);
extern void free(void *);
extern void *sbrk(long);
extern int brk(void *);

static int
check_large_growth(void)
{
        kword_t before;
        kword_t grown;
        kword_t after;
        unsigned char *p;
        unsigned int i;

        before = dsys_brk(0UL);
        if (before == (kword_t)-1L)
                return 10;
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
        return 0;
}

static int
check_free_list_insertion(void)
{
        void *a;
        void *b;
        void *c;
        void *reuse;

        a = malloc(64U);
        b = malloc(64U);
        c = malloc(64U);
        if (a == 0 || b == 0 || c == 0)
                return 20;

        /* Leave B allocated so A and C are non-adjacent.  Freeing C must
         * link it after A rather than replace the free-list head. */
        free(a);
        free(c);
        reuse = malloc(32U);
        if (reuse != a)
                return 21;

        free(reuse);
        free(b);
        return 0;
}

int
main(void)
{
        int rc;

        /* Exercise allocator bookkeeping before the explicit brk shrink.
         * Once a caller moves the break below malloc-owned free blocks, the
         * allocator must not be used again in the same process. */
        rc = check_free_list_insertion();
        if (rc != 0)
                return rc;
        rc = check_large_growth();
        if (rc != 0)
                return rc;
        (void)dsys_writechar(1, 'B');
        (void)dsys_writechar(1, 'R');
        (void)dsys_writechar(1, 'K');
        (void)dsys_writechar(1, '-');
        (void)dsys_writechar(1, 'M');
        (void)dsys_writechar(1, 'A');
        (void)dsys_writechar(1, 'L');
        (void)dsys_writechar(1, 'L');
        (void)dsys_writechar(1, 'O');
        (void)dsys_writechar(1, 'C');
        (void)dsys_writechar(1, '-');
        (void)dsys_writechar(1, 'P');
        (void)dsys_writechar(1, 'A');
        (void)dsys_writechar(1, 'S');
        (void)dsys_writechar(1, 'S');
        (void)dsys_writechar(1, '\n');
        return 0;
}
