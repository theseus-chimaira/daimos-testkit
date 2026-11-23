/* Verify the native DAS driver replaces itself instead of RUN+WAIT.
 * The actual driver is compiled with one mock monitor EXEC veneer.
 * An EXEC failure returns; success never returns in the real monitor.
 * All code is valid ISO C89.
 */
#define main das_driver_main_v1880
#include "das_native_driver.c"
#undef main

extern int puts(const char *);

static kword_t launch_v1880[DAS_DRIVER_EXEC_WORDS];
static unsigned int words_v1880;
static unsigned int calls_v1880;

int dsys_exec(struct sys_exec_v1 *request)
{
    unsigned int i;

    calls_v1880++;
    words_v1880 = (unsigned int)(request->version_words & 0777777UL);
    if (words_v1880 > DAS_DRIVER_EXEC_WORDS)
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
    static kword_t argv_name[] = {
        3UL, PDP10_SIX6('D','A','S',' ',' ',' ')
    };
    static kword_t argv_opt[] = {
        2UL, PDP10_SIX6('-','O',' ',' ',' ',' ')
    };
    static kword_t argv_out[] = {
        6UL, PDP10_SIX6('/','T','M','P','/','O')
    };
    static kword_t argv_src[] = {
        7UL, PDP10_SIX6('/','T','M','P','/','S'),
        PDP10_SIX6('1',' ',' ',' ',' ',' ')
    };
    kword_t *args[4];

    args[0] = argv_name;
    args[1] = argv_opt;
    args[2] = argv_out;
    args[3] = argv_src;
    calls_v1880 = 0U;
    if (das_driver_main_v1880(4, args) != 126 || calls_v1880 != 1U)
        return 1;
    if (launch_v1880[0] != SYS_RUN_HEADER(SYS_EXEC_VERSION_1,
            words_v1880) || launch_v1880[1] != 4UL ||
        launch_v1880[2] != 0UL || words_v1880 != 19U)
        return 2;
    if (!equal_records_v1880(3U, das1_path, 6U) ||
        !equal_records_v1880(9U, das1_chain_name, 3U) ||
        !equal_records_v1880(12U, argv_opt, 2U) ||
        !equal_records_v1880(14U, argv_out, 2U) ||
        !equal_records_v1880(16U, argv_src, 3U))
        return 3;
    args[1] = argv_src;
    calls_v1880 = 0U;
    if (das_driver_main_v1880(2, args) != 1 || calls_v1880 != 0U)
        return 4;
    if (das_driver_main_v1880(0, args) != 1 ||
        das_driver_main_v1880(17, args) != 1)
        return 5;
    puts("PASS: DAS driver uses EXEC with exact phase1 args v1880");
    return 0;
}
