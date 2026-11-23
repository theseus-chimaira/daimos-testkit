/* Native DAS scratch path and cleanup contract, with mocked monitor I/O.
 * Compiles the actual phase-specific DAS source.  No guest filesystem is
 * needed: the mock checks the paths passed to the native UUO veneers.
 * C89, and no fixed-size-path or scratch-file limit is relaxed.
 */
#define DAS_NATIVE 1
#define DAS_NO_MAIN 1
#if defined(TEST_DAS_PHASE2_V1875)
#define DAS_NATIVE_PHASE2_ONLY 1
#else
#define DAS_NATIVE_PHASE1_ONLY 1
#endif
#include "das.c"

extern int puts(const char *);

#define MOCK_MAX_V1875 32
static char opened_v1875[MOCK_MAX_V1875][KPATH_MAX_CHARS + 1U];
static char removed_v1875[MOCK_MAX_V1875][KPATH_MAX_CHARS + 1U];
static int open_count_v1875;
static int remove_count_v1875;
static int close_count_v1875;
static int fail_open_v1875;

static void decode_path_v1875(const kword_t *words, char *out)
{
    unsigned int i;
    unsigned int n;

    n = (unsigned int)words[0];
    if (n > KPATH_MAX_CHARS)
        n = KPATH_MAX_CHARS;
    for (i = 0U; i < n; i++)
        out[i] = (char)(040U +
            ((words[1U + i / 6U] >> (30U - (i % 6U) * 6U)) & 077U));
    out[n] = 0;
}

int dsys_open(kword_t *path, unsigned int flags)
{
    int attempt;

    (void)flags;
    attempt = ++open_count_v1875;
    if (attempt > MOCK_MAX_V1875)
        return -1;
    decode_path_v1875(path, opened_v1875[attempt - 1]);
    return attempt == fail_open_v1875 ? -1 : attempt + 2;
}

int dsys_unlink(kword_t *path)
{
    if (remove_count_v1875 >= MOCK_MAX_V1875)
        return -1;
    decode_path_v1875(path, removed_v1875[remove_count_v1875++]);
    return 0;
}

int dsys_close(int fd)
{
    (void)fd;
    close_count_v1875++;
    return 0;
}

static void reset_mock_v1875(void)
{
    memset(das_native_files, 0, sizeof(das_native_files));
    open_count_v1875 = 0;
    close_count_v1875 = 0;
    remove_count_v1875 = 0;
    fail_open_v1875 = 0;
}

static int find_path_v1875(char names[][KPATH_MAX_CHARS + 1U],
                           int n, const char *wanted)
{
    int i;

    for (i = 0; i < n; ++i)
        if (strcmp(names[i], wanted) == 0)
            return 1;
    return 0;
}

static int check_paths_v1875(const char *base,
                             const char *const *suffixes, int count)
{
    int i;

    if (open_count_v1875 != count || close_count_v1875 != count ||
        remove_count_v1875 != count * 2)
        return 1;
    for (i = 0; i < count; ++i) {
        char expected[KPATH_MAX_CHARS + 1U];
        size_t n;

        strcopy(expected, base, sizeof(expected));
        n = strlen(expected);
        strcopy(expected + n, suffixes[i], sizeof(expected) - n);
        if (!find_path_v1875(opened_v1875, count, expected) ||
            !find_path_v1875(removed_v1875, count * 2, expected))
            return 2;
    }
    return 0;
}

static int check_failure_v1875(void)
{
    static struct asmctx context;

    reset_mock_v1875();
    memset(&context, 0, sizeof(context));
    fail_open_v1875 = 2;
#if defined(TEST_DAS_PHASE2_V1875)
    if (store_init_phase2(&context, "/TEMP/FAIL") == 0)
        return 1;
#else
    if (store_init(&context, "/TEMP/FAIL") == 0)
        return 1;
#endif
    if (open_count_v1875 != 2 || close_count_v1875 != 1 ||
        !find_path_v1875(removed_v1875, remove_count_v1875,
                         "/TEMP/FAIL.DSY"))
        return 2;
    return 0;
}

static int check_boundary_v1875(void)
{
    static struct asmctx context;
    char base[KPATH_MAX_CHARS + 1U];
    unsigned int i;

    reset_mock_v1875();
    memset(&context, 0, sizeof(context));
    base[0] = '/';
    for (i = 1U; i < KPATH_MAX_CHARS - 4U; ++i)
        base[i] = 'A';
    base[i] = 0;
    context.scratch_base = base;
    if (scratch_open(&context.sym_store.spill, base, ".DSY") != 0)
        return 1;
    if (fclose(context.sym_store.spill.file) != 0)
        return 2;
    scratch_remove(&context, &context.sym_store.spill);
    if (strlen(opened_v1875[0]) != KPATH_MAX_CHARS ||
        strlen(removed_v1875[1]) != KPATH_MAX_CHARS)
        return 3;
    base[i++] = 'B';
    base[i] = 0;
    if (scratch_open(&context.lit_store.spill, base, ".DLT") == 0 ||
        open_count_v1875 != 1)
        return 4;
    return 0;
}

int main(void)
{
    static struct asmctx context;
    const char *const suffixes_phase1[] = {
        ".DSY", ".DLT", ".DRP", ".D1R"
    };
    const char *const suffixes_phase2[] = {
        ".DSY", ".DLT", ".DOR", ".DRM"
    };
    int rc;

    reset_mock_v1875();
    memset(&context, 0, sizeof(context));
#if defined(TEST_DAS_PHASE2_V1875)
    if (store_init_phase2(&context, "/TEMP/OUTPUT") != 0)
        return 10;
    if (scratch_open(&context.obj_reloc_spill,
            "/TEMP/OUTPUT", ".DOR") != 0 ||
        scratch_open(&context.relmap_spill,
            "/TEMP/OUTPUT", ".DRM") != 0)
        return 11;
#else
    if (store_init(&context, "/TEMP/OUTPUT") != 0)
        return 12;
#endif
    store_close(&context);
#if defined(TEST_DAS_PHASE2_V1875)
    rc = check_paths_v1875("/TEMP/OUTPUT", suffixes_phase2, 4);
#else
    rc = check_paths_v1875("/TEMP/OUTPUT", suffixes_phase1, 4);
#endif
    if (rc != 0)
        return 20 + rc;
    if (check_failure_v1875() != 0)
        return 30;
    if (check_boundary_v1875() != 0)
        return 40;
    puts("PASS: native DAS scratch paths, cleanup and limits v1875");
    return 0;
}
