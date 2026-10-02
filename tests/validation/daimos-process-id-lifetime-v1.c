#include "dsys.h"
#include "../test_sixbit.h"

#define PGRP_LEADER_MODE       0501U
#define PGRP_KEEPER_MODE       0502U
#define SESSION_OWNER_MODE     0503U
#define SESSION_KEEPER_MODE    0504U
#define DOMAIN_OWNER_MODE      0505U
#define DOMAIN_KEEPER_MODE     0506U
#define PROBE_MODE             0507U

#define OWNER_STATUS           061U
#define PROBE_STATUS           062U
#define DOMAIN_KEEPER_STATUS   063U

#define RUN_PATH_WORDS         3U
#define RUN_ARG_WORDS          2U
#define RUN_PATH_OFF           SYS_RUN_V2_FIXED_WORDS
#define RUN_ARG0_OFF           (RUN_PATH_OFF + RUN_PATH_WORDS)
#define RUN_ARG1_OFF           (RUN_ARG0_OFF + RUN_PATH_WORDS)
#define RUN_MAP_OFF            (RUN_ARG1_OFF + RUN_ARG_WORDS)
#define RUN_BLOCK_WORDS        (RUN_MAP_OFF + 3U)
#define RUN_HOLD_BLOCK_WORDS   (RUN_MAP_OFF + 4U)

static kword_t init_path[] = {
        12UL,
        TEST_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
        TEST_SIX6('M', '/', 'I', 'N', 'I', 'T')
};

static volatile kword_t keep_running;

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
        if (mode == PGRP_LEADER_MODE)
                mode_ch = 'L';
        else if (mode == PGRP_KEEPER_MODE)
                mode_ch = 'K';
        else if (mode == SESSION_OWNER_MODE)
                mode_ch = 'S';
        else if (mode == SESSION_KEEPER_MODE)
                mode_ch = 'T';
        else if (mode == DOMAIN_OWNER_MODE)
                mode_ch = 'D';
        else if (mode == DOMAIN_KEEPER_MODE)
                mode_ch = 'E';
        else
                mode_ch = 'P';
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
        int mode_ch;

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
        mode_ch = mode == PGRP_LEADER_MODE ? 'L' : 'P';
        block[RUN_ARG1_OFF] = 1UL;
        block[RUN_ARG1_OFF + 1U] =
            TEST_SIX6(mode_ch, ' ', ' ', ' ', ' ', ' ');
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
        kword_t word;

        if (argc == 1)
                return 1U;
        if (argc != 2 || argv == 0 || argv[1] == 0 || argv[1][0] != 1UL)
                return 0U;
        word = argv[1][1];
        if (word == TEST_SIX6('L', ' ', ' ', ' ', ' ', ' '))
                return PGRP_LEADER_MODE;
        if (word == TEST_SIX6('K', ' ', ' ', ' ', ' ', ' '))
                return PGRP_KEEPER_MODE;
        if (word == TEST_SIX6('S', ' ', ' ', ' ', ' ', ' '))
                return SESSION_OWNER_MODE;
        if (word == TEST_SIX6('T', ' ', ' ', ' ', ' ', ' '))
                return SESSION_KEEPER_MODE;
        if (word == TEST_SIX6('D', ' ', ' ', ' ', ' ', ' '))
                return DOMAIN_OWNER_MODE;
        if (word == TEST_SIX6('E', ' ', ' ', ' ', ' ', ' '))
                return DOMAIN_KEEPER_MODE;
        if (word == TEST_SIX6('P', ' ', ' ', ' ', ' ', ' '))
                return PROBE_MODE;
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

        if (dsys_close(write_fd) != 0)
                return -1;
        if (dsys_read_words(read_fd, &word, 1U) != 0)
                return -1;
        if (dsys_close(read_fd) != 0)
                return -1;
        if (dsys_procinfo(pid, &info) != 0 || info.state != 4U)
                return -1;
        return 0;
}

static void
spin_forever(void)
{
        for (;;)
                keep_running = (keep_running + 1UL) & 0777777777777UL;
}

static int
wait_exit(unsigned int pid, unsigned int value)
{
        kword_t status;
        int got;

        status = 0UL;
        got = dsys_wait(pid, &status, 0U);
        if (got != (int)pid || SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) != value)
                return -1;
        return 0;
}

static int
kill_and_reap(unsigned int pid)
{
        kword_t status;
        int got;

        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,
            SYS_EVENT_ARG(pid, SYS_EVENT_TERM)) != 0)
                return -1;
        status = 0UL;
        got = dsys_wait(pid, &status, 0U);
        if (got != (int)pid || SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) !=
            (SYS_WAIT_EVENT_FLAG | SYS_EVENT_TERM))
                return -1;
        return 0;
}

static int
probe_slot(unsigned int forbidden)
{
        int pid;

        pid = spawn(PROBE_MODE, SYS_RUN_PGRP_INHERIT, 0U);
        if (pid <= 1 || (unsigned int)pid == forbidden)
                return -1;
        if (wait_exit((unsigned int)pid, PROBE_STATUS) != 0)
                return -1;
        return 0;
}

int
main(int argc, kword_t **argv)
{
        unsigned int mode;
        int leader;
        int keeper;
        int read_fd;
        int write_fd;

        mode = startup_mode(argc, argv);

        if (mode == PGRP_LEADER_MODE) {
                (void)dsys_exit(OWNER_STATUS);
                return OWNER_STATUS;
        }
        if (mode == PGRP_KEEPER_MODE) {
                if (dsys_procctl(SYS_PROCCTL_GETPGRP, 0U) != 2)
                        (void)dsys_exit(070);
                spin_forever();
                return 070;
        }
        if (mode == SESSION_OWNER_MODE) {
                int pid;

                pid = dsys_getpid();
                if (pid <= 1 || dsys_procctl(SYS_PROCCTL_NEWSESSION, 0U) != pid)
                        (void)dsys_exit(071);
                keeper = spawn(SESSION_KEEPER_MODE, SYS_RUN_PGRP_NEW, 0U);
                if (keeper != 3)
                        (void)dsys_exit(072);
                (void)dsys_exit(OWNER_STATUS);
                return OWNER_STATUS;
        }
        if (mode == SESSION_KEEPER_MODE) {
                if (dsys_procctl(SYS_PROCCTL_GETSESSION, 0U) != 2 ||
                    dsys_procctl(SYS_PROCCTL_GETPGRP, 0U) != 3)
                        (void)dsys_exit(073);
                spin_forever();
                return 073;
        }
        if (mode == DOMAIN_OWNER_MODE) {
                int pid;

                pid = dsys_getpid();
                if (pid <= 1 || dsys_procctl(SYS_PROCCTL_NEWSESSION, 0U) != pid ||
                    dsys_procctl(SYS_PROCCTL_NEWDOMAIN, 0U) != pid)
                        (void)dsys_exit(074);
                keeper = spawn(DOMAIN_KEEPER_MODE, SYS_RUN_PGRP_NEW, 0U);
                if (keeper != 3)
                        (void)dsys_exit(075);
                (void)dsys_exit(OWNER_STATUS);
                return OWNER_STATUS;
        }
        if (mode == DOMAIN_KEEPER_MODE) {
                int pid;

                pid = dsys_getpid();
                if (pid != 3 || dsys_procctl(SYS_PROCCTL_GETDOMAIN, 0U) != 2 ||
                    dsys_procctl(SYS_PROCCTL_NEWSESSION, 0U) != pid ||
                    dsys_procctl(SYS_PROCCTL_GETSESSION, 0U) != pid ||
                    dsys_procctl(SYS_PROCCTL_GETPGRP, 0U) != pid ||
                    dsys_procctl(SYS_PROCCTL_GETDOMAIN, 0U) != 2)
                        (void)dsys_exit(076);
                (void)dsys_exit(DOMAIN_KEEPER_STATUS);
                return DOMAIN_KEEPER_STATUS;
        }
        if (mode == PROBE_MODE) {
                (void)dsys_exit(PROBE_STATUS);
                return PROBE_STATUS;
        }

        if (mode != 1U || dsys_getpid() != 1)
                fail('0', 010);
        if (mark('<') != 0)
                fail('1', 011);

        if (new_pipe(&read_fd, &write_fd) != 0)
                fail('2', 012);
        leader = spawn_held(PGRP_LEADER_MODE, SYS_RUN_PGRP_NEW, 0U, write_fd);
        if (leader != 2)
                fail('2', 012);
        if (wait_zombie_by_eof((unsigned int)leader, read_fd, write_fd) != 0)
                fail('Z', 012);
        keeper = spawn(PGRP_KEEPER_MODE, SYS_RUN_PGRP_JOIN,
            (unsigned int)leader);
        if (keeper != 3 || wait_exit((unsigned int)leader, OWNER_STATUS) != 0)
                fail('3', 013);
        if (probe_slot((unsigned int)leader) != 0)
                fail('P', 014);
        if (kill_and_reap((unsigned int)keeper) != 0)
                fail('4', 015);

        leader = spawn(SESSION_OWNER_MODE, SYS_RUN_PGRP_INHERIT, 0U);
        if (leader != 2 || wait_exit((unsigned int)leader, OWNER_STATUS) != 0)
                fail('5', 016);
        if (probe_slot((unsigned int)leader) != 0)
                fail('S', 017);
        if (kill_and_reap(3U) != 0)
                fail('6', 020);

        leader = spawn(DOMAIN_OWNER_MODE, SYS_RUN_PGRP_INHERIT, 0U);
        if (leader != 2 || wait_exit((unsigned int)leader, OWNER_STATUS) != 0)
                fail('7', 021);
        if (probe_slot((unsigned int)leader) != 0)
                fail('D', 022);
        if (wait_exit(3U, DOMAIN_KEEPER_STATUS) != 0)
                fail('8', 023);

        (void)mark('I');
        (void)dsys_exit(0);
        return 0;
}
