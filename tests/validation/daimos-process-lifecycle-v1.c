#include "dsys.h"
#include "../test_sixbit.h"

#define CHILD_EXIT_MODE      0101U
#define ORPHAN_PARENT_MODE   0102U
#define ORPHAN_CHILD_MODE    0103U
#define NO_STDOUT_MODE       0104U
#define FD_MAP_MODE          0105U
#define BURN_COUNT           0400000U

#define RUN_PATH_WORDS       3U
#define RUN_ARG_WORDS        2U
#define RUN_PATH_OFF         SYS_RUN_V2_FIXED_WORDS
#define RUN_ARG0_OFF         (RUN_PATH_OFF + RUN_PATH_WORDS)
#define RUN_ARG1_OFF         (RUN_ARG0_OFF + RUN_PATH_WORDS)
#define RUN_MAP_OFF          (RUN_ARG1_OFF + RUN_ARG_WORDS)
#define RUN_BLOCK_MAX_WORDS  (RUN_MAP_OFF + 4U)

static volatile kword_t burn_word;

static kword_t init_path[] = {
        12UL,
        TEST_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
        TEST_SIX6('M', '/', 'I', 'N', 'I', 'T')
};

static int
mark(int ch)
{
        return dsys_writechar(1, ch);
}

static void
burn(void)
{
        unsigned int i;

        for (i = 0U; i < BURN_COUNT; ++i)
                burn_word = (burn_word + (kword_t)i + 1UL) & 0777777777777UL;
}

static int
spawn(unsigned int mode, unsigned int stdio_mask, int mapped_fd)
{
        kword_t block[RUN_BLOCK_MAX_WORDS];
        struct sys_run_v2 *run;
        unsigned int nmap;
        unsigned int words;
        unsigned int i;
        int mode_ch;

        for (i = 0U; i < RUN_BLOCK_MAX_WORDS; ++i)
                block[i] = 0UL;
        run = (struct sys_run_v2 *)block;
        run->flags = SYS_RUN_PGRP_INHERIT;
        run->pgrp = 0UL;
        run->argc = 2UL;
        run->envc = 0UL;

        for (i = 0U; i < RUN_PATH_WORDS; ++i) {
                block[RUN_PATH_OFF + i] = init_path[i];
                block[RUN_ARG0_OFF + i] = init_path[i];
        }
        if (mode == CHILD_EXIT_MODE)
                mode_ch = 'C';
        else if (mode == ORPHAN_PARENT_MODE)
                mode_ch = 'P';
        else if (mode == ORPHAN_CHILD_MODE)
                mode_ch = 'O';
        else if (mode == NO_STDOUT_MODE)
                mode_ch = 'N';
        else
                mode_ch = 'F';
        block[RUN_ARG1_OFF] = 1UL;
        block[RUN_ARG1_OFF + 1U] =
            TEST_SIX6(mode_ch, ' ', ' ', ' ', ' ', ' ');

        nmap = 0U;
        if ((stdio_mask & 1U) != 0U)
                block[RUN_MAP_OFF + nmap++] = SYS_RUN_FD_MAP(0U, 0U);
        if ((stdio_mask & 2U) != 0U)
                block[RUN_MAP_OFF + nmap++] = SYS_RUN_FD_MAP(1U, 1U);
        if ((stdio_mask & 4U) != 0U)
                block[RUN_MAP_OFF + nmap++] = SYS_RUN_FD_MAP(2U, 2U);
        if (mapped_fd >= 0)
                block[RUN_MAP_OFF + nmap++] =
                    SYS_RUN_FD_MAP(0U, (unsigned int)mapped_fd);
        run->fdmap_count = (kword_t)nmap;
        words = RUN_MAP_OFF + nmap;
        run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2, words);
        return dsys_run(run);
}

static unsigned int
startup_mode(int argc, kword_t **argv)
{
        if (argc == 1)
                return 1U;
        if (argc != 2 || argv == 0 || argv[1] == 0 || argv[1][0] != 1UL)
                return 0U;
        if (argv[1][1] == TEST_SIX6('C', ' ', ' ', ' ', ' ', ' '))
                return CHILD_EXIT_MODE;
        if (argv[1][1] == TEST_SIX6('P', ' ', ' ', ' ', ' ', ' '))
                return ORPHAN_PARENT_MODE;
        if (argv[1][1] == TEST_SIX6('O', ' ', ' ', ' ', ' ', ' '))
                return ORPHAN_CHILD_MODE;
        if (argv[1][1] == TEST_SIX6('N', ' ', ' ', ' ', ' ', ' '))
                return NO_STDOUT_MODE;
        if (argv[1][1] == TEST_SIX6('F', ' ', ' ', ' ', ' ', ' '))
                return FD_MAP_MODE;
        return 0U;
}

static int
status_is(kword_t status, unsigned int value)
{
        return SYS_WAIT_STATUS_KIND(status) == SYS_WAIT_EXITED &&
            SYS_WAIT_STATUS_VALUE(status) == value;
}

static void
fail(int ch, int rc)
{
        (void)mark('!');
        (void)mark(ch);
        (void)dsys_exit(rc);
}

int
main(int argc, kword_t **argv)
{
        kword_t status;
        unsigned int mode;
        int pid;
        int got;

        mode = startup_mode(argc, argv);

        if (mode == CHILD_EXIT_MODE) {
                burn();
                (void)dsys_exit(023);
                return 023;
        }
        if (mode == NO_STDOUT_MODE) {
                if (dsys_writechar(1, 'X') != -1) {
                        (void)dsys_exit(025);
                        return 025;
                }
                (void)dsys_exit(024);
                return 024;
        }
        if (mode == ORPHAN_CHILD_MODE) {
                burn();
                (void)dsys_exit(032);
                return 032;
        }
        if (mode == FD_MAP_MODE) {
                kword_t word;

                if (dsys_read_words(0, &word, 1U) != 1 || word == 0UL ||
                    dsys_close(0) != 0) {
                        (void)dsys_exit(027);
                        return 027;
                }
                (void)dsys_exit(026);
                return 026;
        }
        if (mode == ORPHAN_PARENT_MODE) {
                pid = spawn(ORPHAN_CHILD_MODE, 7U, -1);
                if (pid <= 0)
                        (void)dsys_exit(033);
                (void)dsys_exit(031);
                return 031;
        }

        if (mode != 1U || dsys_getpid() != 1)
                fail('0', 010);
        if (mark('<') != 0)
                fail('1', 011);

        pid = spawn(CHILD_EXIT_MODE, 7U, -1);
        if (pid <= 1)
                fail('2', 012);
        status = 0UL;
        got = dsys_wait((unsigned int)pid, &status, SYS_WAIT_NOHANG);
        if (got != 0)
                fail('3', 013);
        got = dsys_wait((unsigned int)pid, &status, 0U);
        if (got != pid || !status_is(status, 023U))
                fail('4', 014);
        if (dsys_wait((unsigned int)pid, &status, SYS_WAIT_NOHANG) != -1)
                fail('5', 015);

        pid = spawn(NO_STDOUT_MODE, 5U, -1);
        if (pid <= 1)
                fail('6', 016);
        got = dsys_wait((unsigned int)pid, &status, 0U);
        if (got != pid || !status_is(status, 024U))
                fail('7', 017);

        {
                int fd;

                fd = dsys_open(init_path, SYS_O_RDONLY);
                if (fd < 3)
                        fail('C', 024);
                pid = spawn(FD_MAP_MODE, 6U, fd);
                if (pid <= 1)
                        fail('D', 025);
                if (dsys_close(fd) != 0)
                        fail('E', 026);
                got = dsys_wait((unsigned int)pid, &status, 0U);
                if (got != pid || !status_is(status, 026U))
                        fail('F', 027);
        }

        pid = spawn(ORPHAN_PARENT_MODE, 7U, -1);
        if (pid <= 1)
                fail('8', 020);
        got = dsys_wait((unsigned int)pid, &status, 0U);
        if (got != pid || !status_is(status, 031U))
                fail('9', 021);
        got = dsys_wait(0U, &status, 0U);
        if (got <= 1 || !status_is(status, 032U))
                fail('A', 022);
        if (dsys_wait(0U, &status, SYS_WAIT_NOHANG) != -1)
                fail('B', 023);

        (void)mark('P');
        (void)dsys_exit(0);
        return 0;
}
