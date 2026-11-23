/* Test phase1's exact EXEC V1 handoff to phase2 using the actual source.
 * Native filesystem and other unused veneers are removed by GC sections.
 * ISO C89 only.
 */
#define DAS_NATIVE 1
#define DAS_NATIVE_PHASE1_ONLY 1
#define DAS_NO_MAIN 1
#include "das.c"

extern int puts(const char *);

static kword_t launch_v1880[DAS_PHASE2_EXEC_WORDS];
static unsigned int words_v1880;
static unsigned int calls_v1880;

int dsys_exec(struct sys_exec_v1 *request)
{
    unsigned int i;

    calls_v1880++;
    words_v1880 = (unsigned int)(request->version_words & 0777777UL);
    if (words_v1880 > DAS_PHASE2_EXEC_WORDS)
        return -1;
    for (i = 0U; i < words_v1880; ++i)
        launch_v1880[i] = ((kword_t *)request)[i];
    return -1;
}

static int equal_records_v1880(unsigned int offset,
                               const kword_t *expected,
                               unsigned int count)
{
    unsigned int i;

    for (i = 0U; i < count; ++i)
        if (launch_v1880[offset + i] != expected[i])
            return 0;
    return 1;
}

int main(void)
{
    static const das_word_t out_v1880[] = {
        6UL, PDP10_SIX6('/','T','M','P','/','O')
    };
    das_word_t bad[DAS_NATIVE_PATH_WORDS];
    unsigned int i;

    calls_v1880 = 0U;
    if (das_phase2_exec(out_v1880) != 126 || calls_v1880 != 1U)
        return 1;
    if (launch_v1880[0] != SYS_RUN_HEADER(SYS_EXEC_VERSION_1,
            words_v1880) || launch_v1880[1] != 3UL ||
        launch_v1880[2] != 0UL || words_v1880 != 15U)
        return 2;
    if (!equal_records_v1880(3U, das_phase2_exec_path, 6U) ||
        !equal_records_v1880(9U, das_phase2_exec_name, 2U) ||
        !equal_records_v1880(11U, das_phase2_exec_option, 2U) ||
        !equal_records_v1880(13U, out_v1880, 2U))
        return 3;
    calls_v1880 = 0U;
    for (i = 0U; i < DAS_NATIVE_PATH_WORDS; ++i)
        bad[i] = 0UL;
    if (das_phase2_exec((const das_word_t *)0) != 126 ||
        das_phase2_exec(bad) != 126 || calls_v1880 != 0U)
        return 4;
    bad[0] = SYS_RUN_ARG_MAX_CHARS + 1U;
    if (das_phase2_exec(bad) != 126 || calls_v1880 != 0U)
        return 5;
    puts("PASS: DAS1 EXEC handoff uses phase2 path and output v1880");
    return 0;
}
