/* Check native DAS1/DAS2 phase filenames against mock monitor I/O.
 * The real phase-specific source is compiled, not a copied path routine.
 * ISO C89; failures to open the file stop each phase before parsing.
 */
#define DAS_NATIVE 1
#define DAS_NO_MAIN 1
#if defined(TEST_DAS_PHASE2_V1884)
#define DAS_NATIVE_PHASE2_ONLY 1
#else
#define DAS_NATIVE_PHASE1_ONLY 1
#endif
#include "das.c"

#define TEST_MAX_V1884 5
static char opened_v1884[KPATH_MAX_CHARS + 1U];
static char removed_v1884[KPATH_MAX_CHARS + 1U];
static unsigned int opens_v1884;
static unsigned int removes_v1884;

static void decode_v1884(const kword_t *record, char *path)
{
    unsigned int i;
    unsigned int n;

    n = (unsigned int)record[0];
    if (n > KPATH_MAX_CHARS)
        n = KPATH_MAX_CHARS;
    for (i = 0U; i < n; i++)
        path[i] = (char)(040U +
            ((record[1U + i / 6U] >> (30U - (i % 6U) * 6U)) & 077U));
    path[n] = 0;
}

int dsys_open(kword_t *path, unsigned int flags)
{
    (void)flags;
    opens_v1884++;
    decode_v1884(path, opened_v1884);
    return -1;
}

int dsys_unlink(kword_t *path)
{
    removes_v1884++;
    decode_v1884(path, removed_v1884);
    return 0;
}

int dsys_close(int fd)
{
    (void)fd;
    return 0;
}

int dsys_writechar(int fd, int c)
{
    (void)fd;
    return c;
}

int dsys_exec(struct sys_exec_v1 *launch)
{
    (void)launch;
    return -1;
}

int main(void)
{
    static kword_t name[] = { 4UL, PDP10_SIX6('D','A','S','1',' ',' ') };
    static kword_t option[] = { 2UL, PDP10_SIX6('-','O',' ',' ',' ',' ') };
    static kword_t source[] = {
        7UL, PDP10_SIX6('I','N','P','U','T','.'),
        PDP10_SIX6('S',' ',' ',' ',' ',' ')
    };
    static kword_t output_dxr[] = {
        11UL, PDP10_SIX6('P','R','O','G','R','A'),
        PDP10_SIX6('M','.','D','X','R',' ')
    };
    static kword_t output_d2r[] = {
        11UL, PDP10_SIX6('P','R','O','G','R','A'),
        PDP10_SIX6('M','.','D','2','R',' ')
    };
    static kword_t output_bin[] = {
        11UL, PDP10_SIX6('P','R','O','G','R','A'),
        PDP10_SIX6('M','.','B','I','N',' ')
    };
    static kword_t *args[] = { name, option, output_dxr, source };
    static const char *expected[] = {
        "PROGRAM.D2R", "PROGRAM.D2R.D2R", "PROGRAM.BIN.D2R"
    };
    unsigned int i;

    for (i = 0U; i < 3U; ++i) {
        if (i == 1U)
            args[2] = output_d2r;
        else if (i == 2U)
            args[2] = output_bin;
        opens_v1884 = 0U;
        removes_v1884 = 0U;
#if defined(TEST_DAS_PHASE2_V1884)
        if (das_native_main(3, args) == 0)
#else
        if (das_native_main(4, args) == 0)
#endif
            return 10;
        if (opens_v1884 != 1U ||
            strcmp(opened_v1884, expected[i]) != 0)
            return 20;
#if defined(TEST_DAS_PHASE2_V1884)
        if (removes_v1884 != 0U)
            return 30;
#else
        if (removes_v1884 != 1U ||
            strcmp(removed_v1884, expected[i]) != 0)
            return 30;
#endif
    }
    puts("PASS: native phase filename and collision fallback v1884");
    return 0;
}
