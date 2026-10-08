/* KCC regression: jump-to-skip folding must preserve both the loop-carried
 * index and the value used by a conditional return. */
static unsigned
findptr(void **v, unsigned n, void *p)
{
        unsigned i;

        for (i = 0U; i < n; ++i)
                if (v[i] == p)
                        return i + 1U;
        return 0U;
}

int
kcc_loop_return_test(void)
{
        void *v[2];
        unsigned id;

        v[0] = (void *)1;
        v[1] = (void *)2;
        id = findptr(v, 2U, (void *)2);
        return id == 2U ? 0 : (int)id + 0100;
}
