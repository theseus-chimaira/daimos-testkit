/* KCC regression: local word-array base and indexed addresses must agree. */
int
kcc_local_word_array_test(void)
{
        unsigned long a[4];
        unsigned int i;

        a[0] = 0111111111111UL;
        a[1] = 0222222222222UL;
        a[2] = 0333333333333UL;
        a[3] = 0444444444444UL;

        if (a != &a[0])
                return 1;
        if (a + 1 != &a[1])
                return 2;
        for (i = 0U; i < 4U; ++i)
                if (a[i] != (unsigned long)(i + 1U) * 0111111111111UL)
                        return 010 + (int)i;
        return 0;
}
