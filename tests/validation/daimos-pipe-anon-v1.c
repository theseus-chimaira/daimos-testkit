#include "dsys.h"
#include "../test_sixbit.h"

#define WRITER_MODE          0121U
#define BURN_COUNT           0200000U
#define RUN_PATH_WORDS       3U
#define RUN_ARG_WORDS        2U
#define RUN_PATH_OFF         SYS_RUN_V2_FIXED_WORDS
#define RUN_ARG0_OFF         (RUN_PATH_OFF + RUN_PATH_WORDS)
#define RUN_ARG1_OFF         (RUN_ARG0_OFF + RUN_PATH_WORDS)
#define RUN_MAP_OFF          (RUN_ARG1_OFF + RUN_ARG_WORDS)
#define RUN_BLOCK_WORDS      (RUN_MAP_OFF + 2U)

static kword_t init_path[] = {
        12UL,
        TEST_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
        TEST_SIX6('M', '/', 'I', 'N', 'I', 'T')
};

static volatile kword_t burn_word;

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
            WRITER_MODE : 0U;
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

int
main(int argc, kword_t **argv)
{
        kword_t status;
        int read_fd;
        int write_fd;
        int dup_fd;
        int pid;
        int got;
        int ch;
        unsigned int mode;

        mode = startup_mode(argc, argv);

        if (mode == WRITER_MODE) {
                burn();
                if (dsys_writechar(1, 'Z') != 0)
                        (void)dsys_exit(071);
                (void)dsys_exit(070);
                return 070;
        }

        if (mode != 1U)
                fail('0', 010);

        if (new_pipe(&read_fd, &write_fd) != 0)
                fail('1', 011);
        if (dsys_writechar(write_fd, 'A') != 0)
                fail('2', 012);
        ch = dsys_readchar(read_fd);
        if (ch != 'A')
                fail('3', 013);
        if (dsys_close(write_fd) != 0)
                fail('4', 014);
        if (dsys_readchar(read_fd) != -2)
                fail('5', 015);
        if (dsys_close(read_fd) != 0)
                fail('6', 016);

        if (new_pipe(&read_fd, &write_fd) != 0)
                fail('7', 017);
        if (dsys_close(read_fd) != 0)
                fail('8', 020);
        if (dsys_writechar(write_fd, 'B') != -1)
                fail('9', 021);
        if (dsys_close(write_fd) != 0)
                fail('A', 022);

        if (new_pipe(&read_fd, &write_fd) != 0)
                fail('B', 023);
        dup_fd = dsys_dup(write_fd);
        if (dup_fd < 0 || dup_fd == write_fd)
                fail('C', 024);
        if (dsys_close(write_fd) != 0 ||
            dsys_writechar(dup_fd, 'D') != 0 ||
            dsys_readchar(read_fd) != 'D')
                fail('D', 025);
        if (dsys_close(dup_fd) != 0 || dsys_readchar(read_fd) != -2)
                fail('E', 026);
        if (dsys_close(read_fd) != 0)
                fail('F', 027);

        if (new_pipe(&read_fd, &write_fd) != 0)
                fail('G', 030);
        pid = spawn_writer(write_fd);
        if (pid <= 1)
                fail('H', 031);
        if (dsys_close(write_fd) != 0)
                fail('I', 032);
        ch = dsys_readchar(read_fd);
        if (ch != 'Z')
                fail('J', 033);
        if (dsys_readchar(read_fd) != -2)
                fail('K', 034);
        if (dsys_close(read_fd) != 0)
                fail('L', 035);
        status = 0UL;
        got = dsys_wait((unsigned int)pid, &status, 0U);
        if (got != pid || SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) != 070U)
                fail('M', 036);

        if (mark('P') != 0)
                fail('N', 037);
        (void)dsys_exit(0);
        return 0;
}
