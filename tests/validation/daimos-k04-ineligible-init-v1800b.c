/* K04 v1800-B: actual ineligible PID1 and pinned PID3 parent.
 * An independent root supervisor (PID2) controls teardown and HALT.
 * PID4 must be reclaimed directly, without an uncollectable zombie.
 * C89, ASCII, all fault hooks are in a disposable kernel copy. */
#include "dsys.h"
#include "../test_sixbit.h"

#define PATH_WORDS 3U
#define ARG_WORDS 2U
#define PATH_OFF SYS_RUN_V2_FIXED_WORDS
#define ARG0_OFF (PATH_OFF + PATH_WORDS)
#define ARG1_OFF (ARG0_OFF + PATH_WORDS)
#define MAP_OFF (ARG1_OFF + ARG_WORDS)
#define BLOCK_WORDS (MAP_OFF + 5U)

static kword_t init_path[] = {
        12UL,
        TEST_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
        TEST_SIX6('M', '/', 'I', 'N', 'I', 'T')
};

static void
fail(int code)
{
        (void)dsys_writechar(1, '!');
        (void)dsys_writechar(1, code);
        (void)dsys_halt();
        for (;;) { }
}

static int
new_pipe(int *reader, int *writer)
{
        kword_t pair;

        pair = dsys_pipe();
        if (pair == ~(kword_t)0UL)
                return -1;
        *reader = (int)((pair >> 18U) & 0777777UL);
        *writer = (int)(pair & 0777777UL);
        if (*reader < 0 || *reader >= 16 || *writer < 0 ||
            *writer >= 16 || *reader == *writer)
                return -1;
        return 0;
}

/* map[5] and map[6] are explicitly chosen for each new role. */
static int
spawn(int role, int source5, int source6)
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
        for (i = 0U; i < PATH_WORDS; ++i) {
                block[PATH_OFF + i] = init_path[i];
                block[ARG0_OFF + i] = init_path[i];
        }
        block[ARG1_OFF] = 1UL;
        block[ARG1_OFF + 1U] = role == 'S' ?
            TEST_SIX6('S', ' ', ' ', ' ', ' ', ' ') :
            (role == 'P' ?
             TEST_SIX6('P', ' ', ' ', ' ', ' ', ' ') :
             TEST_SIX6('C', ' ', ' ', ' ', ' ', ' '));
        block[MAP_OFF + 0U] = SYS_RUN_FD_MAP(0U, 0U);
        block[MAP_OFF + 1U] = SYS_RUN_FD_MAP(1U, 1U);
        block[MAP_OFF + 2U] = SYS_RUN_FD_MAP(2U, 2U);
        if (role == 'S') {
                count = 4U;
                block[MAP_OFF + 3U] = SYS_RUN_FD_MAP(6U,
                    (unsigned int)source6);
        } else if (role == 'P') {
                count = 5U;
                block[MAP_OFF + 3U] = SYS_RUN_FD_MAP(5U,
                    (unsigned int)source5);
                block[MAP_OFF + 4U] = SYS_RUN_FD_MAP(6U,
                    (unsigned int)source6);
        } else {
                count = 4U;
                block[MAP_OFF + 3U] = SYS_RUN_FD_MAP(5U,
                    (unsigned int)source5);
        }
        run->fdmap_count = count;
        run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
            MAP_OFF + count);
        return dsys_run(run);
}

static void
supervise(void)
{
        struct sys_procinfo info;
        int parent_rd;
        int parent_wr;
        int child_rd;
        int child_wr;
        int td;
        int detail;
        unsigned int i;
        kword_t status;

        if (dsys_getpid() != 2 ||
            dsys_procctl(SYS_PROCCTL_NEWSESSION, 0U) != 2)
                fail('n');
        /* This root-owned process can invoke the normal privileged
         * HALT syscall after PID1 has died. It never waits on INIT. */
        (void)dsys_writechar(1, 'O');
        if (new_pipe(&parent_rd, &parent_wr) != 0 ||
            parent_rd != 3 || parent_wr != 4)
                fail('3');
        if (new_pipe(&child_rd, &child_wr) != 0 ||
            child_rd != 5 || child_wr != 7)
                fail('4');
        if (spawn('P', parent_rd, child_rd) != 3)
                fail('5');
        if (dsys_close(parent_rd) != 0 ||
            dsys_close(child_rd) != 0)
                fail('6');
        for (i = 0U; i < 240U; ++i) {
                if (dsys_procinfo(1U, &info) == 0 &&
                    info.state == 3UL &&
                    dsys_procinfo(3U, &info) == 0 &&
                    info.state == 3UL &&
                    dsys_procinfo(4U, &info) == 0 &&
                    info.state == 3UL && info.ppid == 3UL)
                        break;
                (void)dsys_sleep(4U);
        }
        if (i == 240U)
                fail('7');
        (void)dsys_writechar(1, 'S');
        /* PID1 must own its fatal private FILE continuation before
         * either dying parent or child may be terminated. */
        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,
            SYS_EVENT_ARG(1U, SYS_EVENT_TERM)) != 0)
                fail('8');
        for (i = 0U; i < 240U; ++i) {
                td = dsys_procctl(SYS_PROCCTL_GETTEARDOWN,
                    SYS_TEARDOWN_PREVM_QUERY_ARG(1U));
                detail = dsys_procctl(SYS_PROCCTL_GETTEARDOWN,
                    SYS_TEARDOWN_DETAIL_ARG(1U));
                if (td >= 0 &&
                    SYS_TEARDOWN_STAGE((unsigned int)td) ==
                    SYS_TEARDOWN_FILE && detail >= 0 &&
                    SYS_TEARDOWN_DETAIL_FILE_ERROR(
                        (unsigned int)detail) == 5U)
                        break;
                (void)dsys_sleep(4U);
        }
        if (i == 240U)
                fail('9');
        (void)dsys_writechar(1, 'F');
        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,
            SYS_EVENT_ARG(3U, SYS_EVENT_TERM)) != 0)
                fail('a');
        for (i = 0U; i < 240U; ++i) {
                td = dsys_procctl(SYS_PROCCTL_GETTEARDOWN,
                    SYS_TEARDOWN_PREVM_QUERY_ARG(3U));
                if (td >= 0 &&
                    SYS_TEARDOWN_STAGE((unsigned int)td) ==
                    SYS_TEARDOWN_RUN_VM &&
                    SYS_TEARDOWN_IS_EXIT_PREVM((unsigned int)td))
                        break;
                (void)dsys_sleep(4U);
        }
        if (i == 240U)
                fail('b');
        (void)dsys_writechar(1, 'V');
        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,
            SYS_EVENT_ARG(4U, SYS_EVENT_TERM)) != 0)
                fail('c');
        for (i = 0U; i < 400U; ++i) {
                if (dsys_procinfo(4U, &info) != 0 ||
                    info.state == 0UL)
                        break;
                if (info.state == 4UL)
                        fail('z');
                (void)dsys_sleep(4U);
        }
        if (i == 400U)
                fail('d');
        td = dsys_procctl(SYS_PROCCTL_GETTEARDOWN,
            SYS_TEARDOWN_PREVM_QUERY_ARG(3U));
        if (td < 0 || SYS_TEARDOWN_STAGE((unsigned int)td) !=
            SYS_TEARDOWN_RUN_VM)
                fail('e');
        (void)dsys_writechar(1, 'R');
        /* The fault hook admits INIT's actual SYNC only after PID4
         * reached terminal FREE. INIT can then finish normally. */
        for (i = 0U; i < 4000U; ++i) {
                if (dsys_procinfo(1U, &info) != 0 ||
                    info.state == 0UL)
                        break;
                (void)dsys_sleep(4U);
        }
        if (i == 4000U)
                fail('f');
        for (i = 0U; i < 4000U; ++i) {
                if (dsys_procinfo(3U, &info) == 0 &&
                    info.state == 4UL)
                        break;
                (void)dsys_sleep(4U);
        }
        if (i == 4000U)
                fail('g');
        status = 0UL;
        if (dsys_wait(3U, &status, 0U) != 3)
                fail('h');
        if (dsys_close(parent_wr) != 0 ||
            dsys_close(child_wr) != 0 ||
            dsys_close(6) != 0)
                fail('i');
        if (dsys_procinfo(4U, &info) == 0 &&
            info.state != 0UL)
                fail('j');
        (void)dsys_writechar(1, 'P');
        (void)dsys_halt();
        for (;;) { }
}

int
main(int argc, kword_t **argv)
{
        int fd;
        int ctrl_rd;
        int ctrl_wr;

        if (argc == 2 && argv != 0 && argv[1] != 0 &&
            (argv[1][0] & 0777777UL) == 1UL) {
                if (argv[1][1] ==
                    TEST_SIX6('S', ' ', ' ', ' ', ' ', ' ')) {
                        supervise();
                        return 0;
                }
                if (argv[1][1] ==
                    TEST_SIX6('P', ' ', ' ', ' ', ' ', ' ')) {
                        if (dsys_getpid() != 3 ||
                            spawn('C', 6, -1) != 4)
                                fail('p');
                        (void)dsys_readchar(5);
                        fail('r');
                }
                if (argv[1][1] ==
                    TEST_SIX6('C', ' ', ' ', ' ', ' ', ' ')) {
                        if (dsys_getpid() != 4)
                                fail('q');
                        (void)dsys_readchar(5);
                        fail('s');
                }
                fail('t');
        }

        /* INIT owns an actual D6FS regular descriptor at FD3.
         * The helper remains independent, including its PIPE writer. */
        if (argc != 1 || dsys_getpid() != 1)
                fail('0');
        fd = dsys_open(init_path, SYS_O_RDONLY);
        if (fd != 3)
                fail('1');
        if (new_pipe(&ctrl_rd, &ctrl_wr) != 0 ||
            ctrl_rd != 4 || ctrl_wr != 5)
                fail('2');
        if (spawn('S', -1, ctrl_wr) != 2)
                fail('3');
        if (dsys_close(ctrl_wr) != 0)
                fail('4');
        (void)dsys_readchar(ctrl_rd);
        fail('5');
        return 0;
}
