/* KCC regression: local 9-bit char buffer passed to a six-argument helper. */
static const char var_name[] = "DAS";
static const char var_value[] = "DAS";

static unsigned int
slen(const char *s)
{
        unsigned int n = 0U;

        while (s[n] != 0)
                ++n;
        return n;
}

static int
streq(const char *a, const char *b)
{
        unsigned int i;

        for (i = 0U; a[i] != 0 && b[i] != 0; ++i)
                if (a[i] != b[i])
                        return 0;
        return a[i] == b[i];
}

static int
append(char *dst, unsigned int cap, unsigned int *used, const char *src)
{
        unsigned int i;

        for (i = 0U; src[i] != 0; ++i) {
                if (*used + 1U >= cap)
                        return -1;
                dst[(*used)++] = src[i];
        }
        dst[*used] = 0;
        return 0;
}

static int
expand_value(const char *name, char *dst, unsigned int cap,
    unsigned int *used, const void *automatic, unsigned int depth)
{
        (void)automatic;
        if (depth != 0U || !streq(name, var_name))
                return 0;
        return append(dst, cap, used, var_value);
}

static int
expand(const char *src, char *dst, unsigned int cap)
{
        char name[64];
        unsigned int used = 0U;
        unsigned int i;
        unsigned int n;

        dst[0] = 0;
        for (i = 0U; src[i] != 0; ++i) {
                if (src[i] != '$') {
                        if (used + 1U >= cap)
                                return -1;
                        dst[used++] = src[i];
                        dst[used] = 0;
                        continue;
                }
                ++i;
                if (src[i] != '(')
                        return -1;
                n = 0U;
                ++i;
                while (src[i] != 0 && src[i] != ')') {
                        if (n + 1U >= sizeof(name))
                                return -1;
                        name[n++] = src[i++];
                }
                if (src[i] != ')')
                        return -1;
                name[n] = 0;
                if (n != 3U || name[0] != 'D' || name[1] != 'A' ||
                    name[2] != 'S' || name[3] != 0)
                        return -2;
                if (expand_value(name, dst, cap, &used, 0, 0U) != 0)
                        return -1;
        }
        return 0;
}

int
kcc_sixarg_char_test(void)
{
        char out[64];
        static const char want[] = "DAS -O X";
        unsigned int i;

        i = (unsigned int)expand("$(DAS) -O X", out, sizeof(out));
        if (i != 0U)
                return 010 + (int)(i & 07U);
        if (slen(out) != slen(want))
                return 020 + (int)slen(out);
        for (i = 0U; want[i] != 0; ++i)
                if (out[i] != want[i])
                        return 3;
        return 0;
}
