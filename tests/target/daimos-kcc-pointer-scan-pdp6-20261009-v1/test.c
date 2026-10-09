/* PDP-6 KCC -O=object regression: a conditional early return must not
 * eliminate the increment in the other branch of an indexed for-loop.
 * Verify multiple nonmatching entries before a matching one, then absence.
 * The same shape occurs in KPARSE's KIR graph identity table. */
static unsigned long objects[6];
static void *pointers[5];

unsigned int
scan_pointers(void **values, unsigned int count, void *wanted)
{
        unsigned int i;

        for (i = 0U; i < count; ++i)
                if (values[i] == wanted)
                        return i + 1U;
        return 0U;
}

int
pointer_scan_regression(void)
{
        unsigned int i;

        for (i = 0U; i < 5U; ++i)
                pointers[i] = &objects[i];
        if (scan_pointers(pointers, 5U, &objects[3]) != 4U)
                return 1;
        if (scan_pointers(pointers, 5U, &objects[0]) != 1U)
                return 2;
        if (scan_pointers(pointers, 5U, &objects[5]) != 0U)
                return 3;
        return 0;
}
