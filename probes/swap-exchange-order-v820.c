/* Exhaustive sector-order model for DAIMOS exchange v774.
 * This is a host-side dependency test, not a native PDP-6 acceptance test.
 * Keep all test code in daimos-testkit.
 */
#include <stdio.h>
#include <string.h>

#define LIMIT 16
#define RAM 32

static int check(int aoff, int boff, int sa, int sb)
{
    int mem[RAM], disk[LIMIT], olda[LIMIT], oldb[LIMIT];
    int i, n, step, start, end, scratch;

    for (i = 0; i < RAM; ++i) mem[i] = -1;
    for (i = 0; i < sa; ++i) {
        mem[aoff + i] = 1000 + i;
        olda[i] = 1000 + i;
    }
    for (i = 0; i < sb; ++i) {
        disk[i] = 2000 + i;
        oldb[i] = 2000 + i;
    }
    /* Save the outgoing-only tail before overwriting any A sectors. */
    for (i = sb; i < sa; ++i) disk[i] = mem[aoff + i];
    n = sa < sb ? sa : sb;
    start = boff > aoff ? n - 1 : 0;
    end = boff > aoff ? -1 : n;
    step = boff > aoff ? -1 : 1;
    for (i = start; i != end; i += step) {
        scratch = disk[i];
        disk[i] = mem[aoff + i];
        mem[boff + i] = scratch;
    }
    /* Fetch the incoming-only tail after all outgoing data is saved. */
    for (i = sa; i < sb; ++i) mem[boff + i] = disk[i];
    for (i = 0; i < sa; ++i)
        if (disk[i] != olda[i]) return 1;
    for (i = 0; i < sb; ++i)
        if (mem[boff + i] != oldb[i]) return 2;
    return 0;
}

int main(void)
{
    int a, b, sa, sb, rc;
    unsigned long count = 0;
    for (a = 0; a < 8; ++a)
        for (b = 0; b < 8; ++b)
            for (sa = 1; sa <= LIMIT; ++sa)
                for (sb = 1; sb <= LIMIT; ++sb) {
                    rc = check(a, b, sa, sb);
                    if (rc) {
                        fprintf(stderr, "FAIL a=%d b=%d sa=%d sb=%d side=%d\n",
                                a, b, sa, sb, rc);
                        return 1;
                    }
                    ++count;
                }
    printf("PASS %lu sector-order cases\n", count);
    return 0;
}
