#include "dsys.h"
#include "../test_sixbit.h"

#define CHILD_WRITER_MODE   0121U
#define BURN_COUNT          0200000U
#define RUN_PATH_WORDS      3U
#define RUN_ARG_WORDS       2U
#define RUN_PATH_OFF        SYS_RUN_V2_FIXED_WORDS
#define RUN_ARG0_OFF        (RUN_PATH_OFF + RUN_PATH_WORDS)
#define RUN_ARG1_OFF        (RUN_ARG0_OFF + RUN_PATH_WORDS)
#define RUN_MAP_OFF         (RUN_ARG1_OFF + RUN_ARG_WORDS)
#define RUN_BLOCK_WORDS     (RUN_MAP_OFF + 2U)

#define FIRST_WORDS         6U
#define CONSUME_WORDS       4U
#define SECOND_WORDS        6U
#define REMAIN_WORDS        (FIRST_WORDS - CONSUME_WORDS)
#define FINAL_WORDS         (REMAIN_WORDS + SECOND_WORDS)

static volatile kword_t burn_word;
static kword_t first[FIRST_WORDS];
static kword_t second[SECOND_WORDS];
static kword_t got[FINAL_WORDS];

static kword_t init_path[] = {
        12UL,
        TEST_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
        TEST_SIX6('M', '/', 'I', 'N', 'I', 'T')
};

static void
burn(void)
{
        unsigned int i;

        for (i = 0U; i < BURN_COUNT; ++i)
                burn_word = (burn_word + (kword_t)i + 1UL) & 0777777777777UL;
}

static int
mark(int ch)
{
        return dsys_writechar(1, ch);
}

static void
fail(int ch, int rc)
{
        (void)mark('!');
        (void)mark(ch);
        (void)dsys_exit(rc);
}

static int
new_pipe(int *read_fd, int *write_fd)
{
        kword_t pair;

        pair = dsys_pipe();
        if (pair == ~0UL)
                return -1;
        *read_fd = (int)((pair >> 18U) & 0777777UL);
        *write_fd = (int)(pair & 0777777UL);
        if (*read_fd < 0 || *read_fd >= 16 || *write_fd < 0 ||
            *write_fd >= 16 || *read_fd == *write_fd)
                return -1;
        return 0;
}

static int
spawn_writer(int write_fd)
{
        kword_t block[RUN_BLOCK_WORDS];
        struct sys_run_v2 *run;
        unsigned int i;

        for (i = 0U; i < RUN_BLOCK_WORDS; ++i)
                block[i] = 0UL;
        run = (struct sys_run_v2 *)block;
        run->flags = SYS_RUN_PGRP_INHERIT;
        run->pgrp = 0UL;
        run->fdmap_count = 2UL;
        run->argc = 2UL;
        run->envc = 0UL;
        for (i = 0U; i < RUN_PATH_WORDS; ++i) {
                block[RUN_PATH_OFF + i] = init_path[i];
                block[RUN_ARG0_OFF + i] = init_path[i];
        }
        block[RUN_ARG1_OFF] = 1UL;
        block[RUN_ARG1_OFF + 1U] = TEST_SIX6('W', ' ', ' ', ' ', ' ', ' ');
        block[RUN_MAP_OFF] = SYS_RUN_FD_MAP(1U, (unsigned int)write_fd);
        block[RUN_MAP_OFF + 1U] = SYS_RUN_FD_MAP(2U, 2U);
        run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
            RUN_BLOCK_WORDS);
        return dsys_run(run);
}

static unsigned int
startup_mode(int argc, kword_t **argv)
{
        if (argc == 1)
                return 1U;
        if (argc != 2 || argv == 0 || argv[1] == 0 ||
            (argv[1][0] & 0777777UL) != 1UL)
                return 0U;
        return (((argv[1][1] >> 30U) & 077UL) + 040U) == 'W' ?
            CHILD_WRITER_MODE : 0U;
}

int
main(int argc, kword_t **argv)
{
        kword_t status;
        kword_t word;
        unsigned int i;
        unsigned int mode;
        int rfd;
        int wfd;
        int dupfd;
        int pid;
        int gotpid;

        mode = startup_mode(argc, argv);
        if (mode == CHILD_WRITER_MODE) {
                word = 0765432101234UL;
                burn();
                if (dsys_write_words(1, &word, 1U) != 1)
                        (void)dsys_exit(071);
                (void)dsys_exit(070);
                return 070;
        }
        if (mode != 1U)
                fail('0', 010);

        for (i = 0U; i < FIRST_WORDS; ++i)
                first[i] = 0123456000000UL + (kword_t)i;
        for (i = 0U; i < SECOND_WORDS; ++i)
                second[i] = 0765432000000UL + (kword_t)i;

        if (new_pipe(&rfd, &wfd) != 0)
                fail('1', 011);
        if (dsys_writechar(wfd, 'X') != -1 || dsys_readchar(rfd) != -1)
                fail('2', 012);
        if (dsys_write_words(wfd, first, FIRST_WORDS) != (int)FIRST_WORDS)
                fail('3', 013);
        if (dsys_read_words(rfd, got, CONSUME_WORDS) != (int)CONSUME_WORDS)
                fail('4', 014);
        for (i = 0U; i < CONSUME_WORDS; ++i)
                if (got[i] != first[i])
                        fail('5', 015);
        if (dsys_write_words(wfd, second, SECOND_WORDS) != (int)SECOND_WORDS)
                fail('6', 016);
        if (dsys_read_words(rfd, got, FINAL_WORDS) != (int)FINAL_WORDS)
                fail('7', 017);
        for (i = 0U; i < REMAIN_WORDS; ++i)
                if (got[i] != first[CONSUME_WORDS + i])
                        fail('8', 020);
        for (i = 0U; i < SECOND_WORDS; ++i)
                if (got[REMAIN_WORDS + i] != second[i])
                        fail('9', 021);
        if (dsys_close(wfd) != 0 || dsys_read_words(rfd, &word, 1U) != 0 ||
            dsys_close(rfd) != 0)
                fail('A', 022);

        if (new_pipe(&rfd, &wfd) != 0)
                fail('B', 023);
        if (dsys_close(rfd) != 0 || dsys_write_words(wfd, first, 1U) != -1 ||
            dsys_close(wfd) != 0)
                fail('C', 024);

        if (new_pipe(&rfd, &wfd) != 0)
                fail('D', 025);
        dupfd = dsys_dup(wfd);
        if (dupfd < 0 || dupfd == wfd)
                fail('E', 026);
        if (dsys_close(wfd) != 0 ||
            dsys_write_words(dupfd, first, 1U) != 1 ||
            dsys_read_words(rfd, &word, 1U) != 1 || word != first[0])
                fail('F', 027);
        if (dsys_close(dupfd) != 0 || dsys_read_words(rfd, &word, 1U) != 0 ||
            dsys_close(rfd) != 0)
                fail('G', 030);

        if (new_pipe(&rfd, &wfd) != 0)
                fail('H', 031);
        pid = spawn_writer(wfd);
        if (pid <= 1 || dsys_close(wfd) != 0)
                fail('I', 032);
        if (dsys_read_words(rfd, &word, 1U) != 1 ||
            word != 0765432101234UL)
                fail('J', 033);
        if (dsys_read_words(rfd, &word, 1U) != 0 || dsys_close(rfd) != 0)
                fail('K', 034);
        status = 0UL;
        gotpid = dsys_wait((unsigned int)pid, &status, 0U);
        if (gotpid != pid || SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) != 070U)
                fail('L', 035);

        if (mark('P') != 0)
                fail('M', 036);
        (void)dsys_exit(0);
        return 0;
}
