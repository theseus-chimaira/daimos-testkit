/* KCC regression: a register-ABI call with an indexed local argument must
 * not change the caller's stack pointer. */
static unsigned long
take(unsigned long value)
{
        return value;
}

int
kcc_indexed_call_test(void)
{
        unsigned long a[3];
        unsigned long guard;
        unsigned int i;

        a[0] = 0111111111111UL;
        a[1] = 0222222222222UL;
        a[2] = 0333333333333UL;
        guard = 0765432107654UL;
        for (i = 0U; i < 3U; ++i)
                (void)take(a[i]);
        if (guard != 0765432107654UL)
                return 1;
        if (a[0] != 0111111111111UL || a[1] != 0222222222222UL ||
            a[2] != 0333333333333UL)
                return 2;
        return 0;
}
