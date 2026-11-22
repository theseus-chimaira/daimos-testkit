/* K04 v1798: real session leader and live member under fatal HUP.
 * The member's exact D6FS FILE SYNC is refused by scratch VFS code.
 * An independent INIT monitors the leader and member's fatal FILE
 * owners, verifies eventual WAIT and resource reclamation, then HALTs.
 * ASCII, C89, no production KCORE changes. */
#include "dsys.h"
#include "../test_sixbit.h"

#define PATH_WORDS 3U
#define ARG_WORDS 2U
#define PATH_OFF SYS_RUN_V2_FIXED_WORDS
#define ARG0_OFF (PATH_OFF + PATH_WORDS)
#define ARG1_OFF (ARG0_OFF + PATH_WORDS)
#define MAP_OFF (ARG1_OFF + ARG_WORDS)
#define BLOCK_WORDS (MAP_OFF + 6U)

static kword_t init_path[] = {
        12UL,
        TEST_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
        TEST_SIX6('M', '/', 'I', 'N', 'I', 'T')
};

static void
fail(int letter)
{
        (void)dsys_writechar(1, '!');
        (void)dsys_writechar(1, letter);
        (void)dsys_halt();
        for (;;) { }
}

static int
new_pipe(int *reader, int *writer)
{
        kword_t both;

        both = dsys_pipe();
        if (both == ~(kword_t)0UL)
                return -1;
        *reader = (int)((both >> 18U) & 0777777UL);
        *writer = (int)(both & 0777777UL);
        if (*reader < 0 || *reader >= 16 || *writer < 0 ||
            *writer >= 16 || *reader == *writer)
                return -1;
        return 0;
}

static int
spawn(int leader, int first, int second, int regular_fd)
{
        kword_t block[BLOCK_WORDS];
        struct sys_run_v2 *run;
        unsigned int i;
        unsigned int count;

        for (i = 0U; i < BLOCK_WORDS; ++i)
                block[i] = 0UL;
        run = (struct sys_run_v2 *)block;
        run->flags = SYS_RUN_PGRP_INHERIT;
        run->argc = 2UL;
        run->envc = 0UL;
        count = leader ? 6U : 5U;
        run->fdmap_count = (kword_t)count;
        for (i = 0U; i < PATH_WORDS; ++i) {
                block[PATH_OFF + i] = init_path[i];
                block[ARG0_OFF + i] = init_path[i];
        }
        block[ARG1_OFF] = 1UL;
        block[ARG1_OFF + 1U] = leader ?
            TEST_SIX6('L', ' ', ' ', ' ', ' ', ' ') :
            TEST_SIX6('M', ' ', ' ', ' ', ' ', ' ');
        block[MAP_OFF + 0U] = SYS_RUN_FD_MAP(0U, 0U);
        block[MAP_OFF + 1U] = SYS_RUN_FD_MAP(1U, 1U);
        block[MAP_OFF + 2U] = SYS_RUN_FD_MAP(2U, 2U);
        if (leader) {
                block[MAP_OFF + 3U] = SYS_RUN_FD_MAP(4U,
                    (unsigned int)first);
                block[MAP_OFF + 4U] = SYS_RUN_FD_MAP(5U,
                    (unsigned int)second);
                block[MAP_OFF + 5U] = SYS_RUN_FD_MAP(6U,
                    (unsigned int)regular_fd);
        } else {
                block[MAP_OFF + 3U] = SYS_RUN_FD_MAP(5U,
                    (unsigned int)second);
                block[MAP_OFF + 4U] = SYS_RUN_FD_MAP(6U,
                    (unsigned int)regular_fd);
        }
        run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
            MAP_OFF + count);
        return dsys_run(run);
}

int
main(int argc, kword_t **argv)
{
        struct sys_meminfo before;
        struct sys_meminfo after;
        struct sys_procinfo leader_info;
        struct sys_procinfo member_info;
        kword_t status;
        unsigned int i;
        unsigned int saw_hup_hold;
        int fd;
        int ready_rd;
        int ready_wr;
        int member_rd;
        int member_wr;
        int pid;
        int leader_td;
        int member_td;
        int detail;

        if (argc == 2 && argv != 0 && argv[1] != 0 &&
            (argv[1][0] & 0777777UL) == 1UL) {
                if (argv[1][1] ==
                    TEST_SIX6('M', ' ', ' ', ' ', ' ', ' ')) {
                        if (dsys_getpid() != 3)
                                fail('m');
                        /* INIT retains the real PIPE writer, so this
                         * wait does not complete before fatal HUP. */
                        (void)dsys_readchar(5);
                        fail('r');
                }
                if (argv[1][1] !=
                    TEST_SIX6('L', ' ', ' ', ' ', ' ', ' '))
                        fail('l');
                if (dsys_getpid() != 2 ||
                    dsys_procctl(SYS_PROCCTL_NEWSESSION, 0U) != 2 ||
                    dsys_procctl(SYS_PROCCTL_TTY_ATTACH, 0U) != 0)
                        fail('t');
                pid = spawn(0, 0, 5, 6);
                if (pid != 3)
                        fail('c');
                if (dsys_close(5) != 0 || dsys_close(6) != 0 ||
                    dsys_writechar(4, 'R') != 0 ||
                    dsys_close(4) != 0)
                        fail('d');
                status = 0UL;
                (void)dsys_wait(3U, &status, 0U);
                fail('w');
        }

        if (argc != 1 || dsys_getpid() != 1)
                fail('0');
        if (dsys_meminfo(&before) != 0)
                fail('1');
        fd = dsys_open(init_path, SYS_O_RDONLY);
        if (fd != 3)
                fail('2');
        if (new_pipe(&ready_rd, &ready_wr) != 0 ||
            ready_rd != 4 || ready_wr != 5)
                fail('3');
        if (new_pipe(&member_rd, &member_wr) != 0 ||
            member_rd != 6 || member_wr != 7)
                fail('4');
        pid = spawn(1, ready_wr, member_rd, fd);
        if (pid != 2)
                fail('5');
        if (dsys_close(fd) != 0 || dsys_close(ready_wr) != 0 ||
            dsys_close(member_rd) != 0)
                fail('6');
        if (dsys_readchar(ready_rd) != 'R' ||
            dsys_close(ready_rd) != 0)
                fail('7');
        /* Require two real SLEEPing processes before TERM, so neither
         * the member's pending HUP nor the leader's WAIT is confused
         * with an earlier foreign direct-close path. */
        for (i = 0U; i < 120U; ++i) {
                if (dsys_procinfo(2U, &leader_info) == 0 &&
                    leader_info.state == 3UL &&
                    dsys_procinfo(3U, &member_info) == 0 &&
                    member_info.state == 3UL)
                        break;
                (void)dsys_sleep(4U);
        }
        if (i == 120U)
                fail('8');
        (void)dsys_writechar(1, 'S');
        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,
            SYS_EVENT_ARG(2U, SYS_EVENT_TERM)) != 0)
                fail('9');

        saw_hup_hold = 0U;
        for (i = 0U; i < 400U; ++i) {
                leader_td = dsys_procctl(SYS_PROCCTL_GETTEARDOWN,
                    SYS_TEARDOWN_PREVM_QUERY_ARG(2U));
                member_td = dsys_procctl(SYS_PROCCTL_GETTEARDOWN,
                    SYS_TEARDOWN_PREVM_QUERY_ARG(3U));
                detail = dsys_procctl(SYS_PROCCTL_GETTEARDOWN,
                    SYS_TEARDOWN_DETAIL_ARG(3U));
                if (leader_td >= 0 && member_td >= 0 &&
                    SYS_TEARDOWN_STAGE((unsigned int)leader_td) ==
                    SYS_TEARDOWN_FILE &&
                    SYS_TEARDOWN_STAGE((unsigned int)member_td) ==
                    SYS_TEARDOWN_FILE && detail >= 0 &&
                    SYS_TEARDOWN_DETAIL_FILE_ERROR((unsigned int)detail)
                    == 5U) {
                        saw_hup_hold = 1U;
                        break;
                }
                (void)dsys_sleep(4U);
        }
        if (!saw_hup_hold)
                fail('a');
        (void)dsys_writechar(1, 'H');
        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,
            SYS_EVENT_ARG(3U, SYS_EVENT_HUP)) != -1)
                fail('b');

        /* Do not block blindly in WAIT: require both children to have
         * published terminal ZOMB first, or halt with a diagnostic. */
        for (i = 0U; i < 1800U; ++i) {
                if (dsys_procinfo(2U, &leader_info) == 0 &&
                    leader_info.state == 4UL &&
                    dsys_procinfo(3U, &member_info) == 0 &&
                    member_info.state == 4UL)
                        break;
                (void)dsys_sleep(4U);
        }
        if (i == 1800U)
                fail('z');
        status = 0UL;
        if (dsys_wait(2U, &status, 0U) != 2)
                fail('e');
        status = 0UL;
        if (dsys_wait(3U, &status, 0U) != 3)
                fail('f');
        if (dsys_close(member_wr) != 0 ||
            dsys_meminfo(&after) != 0 ||
            before.process_slots_used != after.process_slots_used ||
            before.process_words != after.process_words ||
            before.file_slots_used != after.file_slots_used)
                fail('g');
        (void)dsys_writechar(1, 'P');
        (void)dsys_halt();
        return 0;
}
