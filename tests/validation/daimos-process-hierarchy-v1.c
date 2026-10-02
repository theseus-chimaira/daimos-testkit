#include "dsys.h"
#include "../test_sixbit.h"

#define LEADER_MODE          0201U
#define JOIN_MODE            0202U
#define SESSION_MODE         0203U
#define LEADER_STATUS        041U
#define JOIN_STATUS          042U
#define SESSION_STATUS       043U
#define PROC_STATE_ZOMB      4U

#define RUN_PATH_WORDS       3U
#define RUN_ARG_WORDS        2U
#define RUN_PATH_OFF         SYS_RUN_V2_FIXED_WORDS
#define RUN_ARG0_OFF         (RUN_PATH_OFF + RUN_PATH_WORDS)
#define RUN_ARG1_OFF         (RUN_ARG0_OFF + RUN_PATH_WORDS)
#define RUN_MAP_OFF          (RUN_ARG1_OFF + RUN_ARG_WORDS)
#define RUN_BLOCK_WORDS      (RUN_MAP_OFF + 3U)
#define RUN_HOLD_BLOCK_WORDS (RUN_MAP_OFF + 4U)

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
fail(int ch, int rc)
{
        (void)mark('!');
        (void)mark(ch);
        (void)dsys_exit(rc);
}

static int
spawn(unsigned int mode, unsigned int pgrp_mode, unsigned int pgrp)
{
        kword_t block[RUN_BLOCK_WORDS];
        struct sys_run_v2 *run;
        unsigned int i;
        int mode_ch;

        for (i = 0U; i < RUN_BLOCK_WORDS; ++i)
                block[i] = 0UL;
        run = (struct sys_run_v2 *)block;
        run->flags = (kword_t)pgrp_mode;
        run->pgrp = (kword_t)pgrp;
        run->fdmap_count = 3UL;
        run->argc = 2UL;
        run->envc = 0UL;
        for (i = 0U; i < RUN_PATH_WORDS; ++i) {
                block[RUN_PATH_OFF + i] = init_path[i];
                block[RUN_ARG0_OFF + i] = init_path[i];
        }
        mode_ch = mode == LEADER_MODE ? 'L' :
            (mode == JOIN_MODE ? 'J' : 'S');
        block[RUN_ARG1_OFF] = 1UL;
        block[RUN_ARG1_OFF + 1U] =
            TEST_SIX6(mode_ch, ' ', ' ', ' ', ' ', ' ');
        block[RUN_MAP_OFF] = SYS_RUN_FD_MAP(0U, 0U);
        block[RUN_MAP_OFF + 1U] = SYS_RUN_FD_MAP(1U, 1U);
        block[RUN_MAP_OFF + 2U] = SYS_RUN_FD_MAP(2U, 2U);
        run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
            RUN_BLOCK_WORDS);
        return dsys_run(run);
}

static int
spawn_held(unsigned int mode, unsigned int pgrp_mode, unsigned int pgrp,
    int hold_fd)
{
        kword_t block[RUN_HOLD_BLOCK_WORDS];
        struct sys_run_v2 *run;
        unsigned int i;

        for (i = 0U; i < RUN_HOLD_BLOCK_WORDS; ++i)
                block[i] = 0UL;
        run = (struct sys_run_v2 *)block;
        run->flags = (kword_t)pgrp_mode;
        run->pgrp = (kword_t)pgrp;
        run->fdmap_count = 4UL;
        run->argc = 2UL;
        run->envc = 0UL;
        for (i = 0U; i < RUN_PATH_WORDS; ++i) {
                block[RUN_PATH_OFF + i] = init_path[i];
                block[RUN_ARG0_OFF + i] = init_path[i];
        }
        block[RUN_ARG1_OFF] = 1UL;
        block[RUN_ARG1_OFF + 1U] =
            TEST_SIX6(mode == LEADER_MODE ? 'L' : 'J',
            ' ', ' ', ' ', ' ', ' ');
        block[RUN_MAP_OFF] = SYS_RUN_FD_MAP(0U, 0U);
        block[RUN_MAP_OFF + 1U] = SYS_RUN_FD_MAP(1U, 1U);
        block[RUN_MAP_OFF + 2U] = SYS_RUN_FD_MAP(2U, 2U);
        block[RUN_MAP_OFF + 3U] = SYS_RUN_FD_MAP(3U, (unsigned int)hold_fd);
        run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
            RUN_HOLD_BLOCK_WORDS);
        return dsys_run(run);
}

static unsigned int
startup_mode(int argc, kword_t **argv)
{
        if (argc == 1)
                return 1U;
        if (argc != 2 || argv == 0 || argv[1] == 0 || argv[1][0] != 1UL)
                return 0U;
        if (argv[1][1] == TEST_SIX6('L', ' ', ' ', ' ', ' ', ' '))
                return LEADER_MODE;
        if (argv[1][1] == TEST_SIX6('J', ' ', ' ', ' ', ' ', ' '))
                return JOIN_MODE;
        if (argv[1][1] == TEST_SIX6('S', ' ', ' ', ' ', ' ', ' '))
                return SESSION_MODE;
        return 0U;
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
wait_zombie_by_eof(unsigned int pid, int read_fd, int write_fd)
{
        struct sys_procinfo info;
        kword_t word;

        if (dsys_close(write_fd) != 0 ||
            dsys_read_words(read_fd, &word, 1U) != 0 ||
            dsys_close(read_fd) != 0)
                return -1;
        if (dsys_procinfo(pid, &info) != 0 || info.state != PROC_STATE_ZOMB)
                return -1;
        return 0;
}

static int
status_is(kword_t status, unsigned int value)
{
        return SYS_WAIT_STATUS_KIND(status) == SYS_WAIT_EXITED &&
            SYS_WAIT_STATUS_VALUE(status) == value;
}

static int
read_s6rec_is(kword_t *path, unsigned int chars, kword_t word)
{
        kword_t buf[2];
        int fd;
        int n;

        fd = dsys_open(path, SYS_O_RDONLY);
        if (fd < 3)
                return -1;
        n = dsys_read_words(fd, buf, 2U);
        if (dsys_close(fd) != 0 || n != 2 ||
            buf[0] != (010000000000UL | (kword_t)chars) || buf[1] != word)
                return -1;
        return 0;
}

int
main(int argc, kword_t **argv)
{
        static kword_t state2[] = {
                13UL,
                TEST_SIX6('/', 'P', 'R', 'O', 'C', '/'),
                TEST_SIX6('2', '/', 'S', 'T', 'A', 'T'),
                TEST_SIX6('E', ' ', ' ', ' ', ' ', ' ')
        };
        static kword_t ppid2[] = {
                12UL,
                TEST_SIX6('/', 'P', 'R', 'O', 'C', '/'),
                TEST_SIX6('2', '/', 'P', 'P', 'I', 'D')
        };
        struct sys_meminfo mem;
        kword_t status;
        unsigned int seen;
        int pid;
        int leader;
        int joined;
        int got;
        int read_fd;
        int write_fd;
        unsigned int mode;
        unsigned int expected_pgrp;

        mode = startup_mode(argc, argv);
        expected_pgrp = mode == JOIN_MODE ? 2U : 0U;

        if (mode == LEADER_MODE) {
                pid = dsys_getpid();
                if (pid <= 1 || dsys_procctl(SYS_PROCCTL_GETPGRP, 0U) != pid ||
                    dsys_procctl(SYS_PROCCTL_GETSESSION, 0U) != 1 ||
                    dsys_procctl(SYS_PROCCTL_GETDOMAIN, 0U) != 1)
                        (void)dsys_exit(051);
                (void)dsys_exit(LEADER_STATUS);
                return LEADER_STATUS;
        }
        if (mode == JOIN_MODE) {
                if (expected_pgrp == 0U ||
                    dsys_procctl(SYS_PROCCTL_GETPGRP, 0U) !=
                    (int)expected_pgrp ||
                    dsys_procctl(SYS_PROCCTL_GETSESSION, 0U) != 1 ||
                    dsys_procctl(SYS_PROCCTL_GETDOMAIN, 0U) != 1)
                        (void)dsys_exit(052);
                (void)dsys_exit(JOIN_STATUS);
                return JOIN_STATUS;
        }
        if (mode == SESSION_MODE) {
                pid = dsys_getpid();
                if (pid <= 1 ||
                    dsys_procctl(SYS_PROCCTL_NEWSESSION, 0U) != pid ||
                    dsys_procctl(SYS_PROCCTL_GETPGRP, 0U) != pid ||
                    dsys_procctl(SYS_PROCCTL_GETSESSION, 0U) != pid ||
                    dsys_procctl(SYS_PROCCTL_GETDOMAIN, 0U) != 1)
                        (void)dsys_exit(053);
                if (spawn(JOIN_MODE, SYS_RUN_PGRP_JOIN, 1U) != -1)
                        (void)dsys_exit(054);
                if (dsys_procctl(SYS_PROCCTL_NEWDOMAIN, 0U) != pid ||
                    dsys_procctl(SYS_PROCCTL_GETDOMAIN, 0U) != pid)
                        (void)dsys_exit(055);
                (void)dsys_exit(SESSION_STATUS);
                return SESSION_STATUS;
        }

        if (mode != 1U || dsys_getpid() != 1 ||
            dsys_procctl(SYS_PROCCTL_GETPGRP, 0U) != 1 ||
            dsys_procctl(SYS_PROCCTL_GETSESSION, 0U) != 1 ||
            dsys_procctl(SYS_PROCCTL_GETDOMAIN, 0U) != 1)
                fail('0', 010);
        if (mark('<') != 0)
                fail('1', 011);

        if (spawn(LEADER_MODE, SYS_RUN_PGRP_NEW, 7U) != -1 ||
            spawn(JOIN_MODE, SYS_RUN_PGRP_JOIN, 077U) != -1)
                fail('2', 012);
        if (dsys_meminfo(&mem) != 0 || mem.process_slots_used != 2UL)
                fail('3', 013);

        if (new_pipe(&read_fd, &write_fd) != 0)
                fail('4', 014);
        leader = spawn_held(LEADER_MODE, SYS_RUN_PGRP_NEW, 0U, write_fd);
        if (leader != 2 || wait_zombie_by_eof((unsigned int)leader,
            read_fd, write_fd) != 0)
                fail('4', 014);
        if (read_s6rec_is(state2, 4U,
            TEST_SIX6('Z', 'O', 'M', 'B', ' ', ' ')) != 0)
                fail('5', 015);
        if (read_s6rec_is(ppid2, 1U,
            TEST_SIX6('1', ' ', ' ', ' ', ' ', ' ')) != 0)
                fail('D', 025);

        joined = spawn(JOIN_MODE, SYS_RUN_PGRP_JOIN, (unsigned int)leader);
        if (joined <= leader)
                fail('6', 016);

        seen = 0U;
        got = dsys_wait(SYS_WAIT_PGRP_FLAG | (unsigned int)leader,
            &status, 0U);
        if (got == leader && status_is(status, LEADER_STATUS))
                seen |= 1U;
        else if (got == joined && status_is(status, JOIN_STATUS))
                seen |= 2U;
        else
                fail('7', 017);
        got = dsys_wait(SYS_WAIT_PGRP_FLAG | (unsigned int)leader,
            &status, 0U);
        if (got == leader && status_is(status, LEADER_STATUS))
                seen |= 1U;
        else if (got == joined && status_is(status, JOIN_STATUS))
                seen |= 2U;
        else
                fail('8', 020);
        if (seen != 3U || dsys_wait(SYS_WAIT_PGRP_FLAG |
            (unsigned int)leader, &status, SYS_WAIT_NOHANG) != -1)
                fail('9', 021);

        pid = spawn(SESSION_MODE, SYS_RUN_PGRP_INHERIT, 0U);
        if (pid <= 1)
                fail('A', 022);
        got = dsys_wait((unsigned int)pid, &status, 0U);
        if (got != pid || !status_is(status, SESSION_STATUS))
                fail('B', 023);

        if (dsys_procctl(077U, 0U) != -1 ||
            dsys_procctl(SYS_PROCCTL_GETPGRP, 1U) != -1)
                fail('C', 024);

        (void)mark('H');
        (void)dsys_exit(0);
        return 0;
}
