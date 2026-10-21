/* Boundaries and SIXBIT semantics of the shared DSH/ED/EX line core. */
#include <stdio.h>
#include "edcore.h"

static int bad;

static void
check(int yes, const char *what)
{
        if (!yes) {
                fprintf(stderr, "FAIL edcore: %s\n", what);
                ++bad;
        }
}

int
main(void)
{
        kword_t words[2] = { 0, 0 };
        struct edcore_line line;
        unsigned int i;

        line.words = words;
        line.length = 0U;
        line.capacity = 12U;
        for (i = 0U; i < 12U; ++i)
                check(edcore_insert(&line, i, 'A' + (int)i) == 0,
                    "append across word boundary");
        check(line.length == 12U, "full line length");
        check(edcore_insert(&line, 0U, 'X') != 0, "capacity limit");
        for (i = 0U; i < 12U; ++i)
                check(edcore_get(&line, i) == 'A' + (int)i,
                    "packed ordering");
        check(edcore_replace(&line, 5U, 'Z') == 0, "replace");
        check(edcore_get(&line, 5U) == 'Z', "replaced character");
        check(edcore_delete(&line, 5U) == 0, "delete in middle");
        check(edcore_get(&line, 5U) == 'G', "shift across word boundary");
        check(line.length == 11U, "delete length");
        check(edcore_insert(&line, 0U, 'X') == 0, "prepend");
        check(edcore_get(&line, 0U) == 'X', "prepend position");
        check(edcore_get(&line, 6U) == 'G', "preserve shifted word");
        check(edcore_delete(&line, 11U) == 0, "delete end");
        check(edcore_get(&line, 11U) < 0, "out of bounds");
        check(edcore_insert(&line, 15U, 'X') != 0, "invalid position");
        check(edcore_replace(&line, 0U, 0) != 0, "invalid character");
        while (line.length > 0U)
                check(edcore_delete(&line, 0U) == 0, "empty from front");
        check(edcore_get(&line, 0U) < 0, "empty line");
        if (bad != 0)
                return 1;
        puts("PASS edcore 20261021 v1");
        return 0;
}
