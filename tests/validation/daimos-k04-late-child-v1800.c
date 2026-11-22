/* K04 v1800-A: PID3 exits after PID2 entered physically pinned PREVM.
 * INIT must inherit PID3's terminal WAIT while PID2 cannot be reaped.
 * C89, ASCII, disposable PDP-6 guest. */
#include "dsys.h"
#include "../test_sixbit.h"

#define PATH_WORDS 3U
#define ARG_WORDS 2U
#define PATH_OFF SYS_RUN_V2_FIXED_WORDS
#define ARG0_OFF (PATH_OFF + PATH_WORDS)
#define ARG1_OFF (ARG0_OFF + PATH_WORDS)
#define MAP_OFF (ARG1_OFF + ARG_WORDS)
#define MAP_COUNT 5U
#define BLOCK_WORDS (MAP_OFF + MAP_COUNT)

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

static int
spawn(int child, int reader, int writer)
{
        kword_t block[BLOCK_WORDS];
        struct sys_run_v2 *run;
        unsigned int i;

        for (i = 0U; i < BLOCK_WORDS; ++i)
                block[i] = 0UL;
        run = (struct sys_run_v2 *)block;
        run->flags = SYS_RUN_PGRP_INHERIT;
        run->argc = 2UL;
        run->fdmap_count = MAP_COUNT;
        for (i = 0U; i < PATH_WORDS; ++i) {
                block[PATH_OFF + i] = init_path[i];
                block[ARG0_OFF + i] = init_path[i];
        }
        block[ARG1_OFF] = 1UL;
        block[ARG1_OFF + 1U] = child ?
            TEST_SIX6('C', ' ', ' ', ' ', ' ', ' ') :
            TEST_SIX6('P', ' ', ' ', ' ', ' ', ' ');
        block[MAP_OFF + 0U] = SYS_RUN_FD_MAP(0U, 0U);
        block[MAP_OFF + 1U] = SYS_RUN_FD_MAP(1U, 1U);
        block[MAP_OFF + 2U] = SYS_RUN_FD_MAP(2U, 2U);
        block[MAP_OFF + 3U] = SYS_RUN_FD_MAP(5U, (unsigned int)reader);
        block[MAP_OFF + 4U] = SYS_RUN_FD_MAP(6U, (unsigned int)writer);
        run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
            BLOCK_WORDS);
        return dsys_run(run);
}

int
main(int argc, kword_t **argv)
{
        struct sys_procinfo info;
        struct sys_meminfo before;
        struct sys_meminfo after;
        kword_t status;
        unsigned int i;
        int parent_rd;
        int parent_wr;
        int child_rd;
        int child_wr;
        int pid;
        int td;

        if (argc == 2 && argv != 0 && argv[1] != 0 &&
            (argv[1][0] & 0777777UL) == 1UL) {
                if (argv[1][1] ==
                    TEST_SIX6('C', ' ', ' ', ' ', ' ', ' ')) {
                        if (dsys_getpid() != 3)
                                fail('c');
                        /* The INIT-owned writer keeps this reader asleep.
                         * Fatal TERM will exit via the private stack. */
                        (void)dsys_readchar(5);
                        fail('r');
                }
                if (argv[1][1] !=
                    TEST_SIX6('P', ' ', ' ', ' ', ' ', ' ') ||
                    dsys_getpid() != 2)
                        fail('p');
                pid = spawn(1, 5, 6);
                if (pid != 3)
                        fail('q');
                /* The child has inherited its actual parent PID2. */
                (void)dsys_readchar(5);
                fail('s');
        }

        if (argc != 1 || dsys_getpid() != 1 ||
            dsys_meminfo(&before) != 0)
                fail('0');
        if (new_pipe(&parent_rd, &parent_wr) != 0 ||
            parent_rd != 3 || parent_wr != 4)
                fail('1');
        if (new_pipe(&child_rd, &child_wr) != 0 ||
            child_rd != 5 || child_wr != 6)
                fail('2');
        pid = spawn(0, parent_rd, child_rd);
        if (pid != 2)
                fail('3');
        if (dsys_close(parent_rd) != 0 ||
            dsys_close(child_rd) != 0)
                fail('4');

        /* Do not TERM a RUN constructor or an unblocked waiter. */
        for (i = 0U; i < 200U; ++i) {
                if (dsys_procinfo(2U, &info) == 0 &&
                    info.state == 3UL &&
                    dsys_procinfo(3U, &info) == 0 &&
                    info.state == 3UL)
                        break;
                (void)dsys_sleep(4U);
        }
        if (i == 200U)
                fail('5');
        (void)dsys_writechar(1, 'S');
        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,
            SYS_EVENT_ARG(2U, SYS_EVENT_TERM)) != 0)
                fail('6');
        for (i = 0U; i < 200U; ++i) {
                td = dsys_procctl(SYS_PROCCTL_GETTEARDOWN,
                    SYS_TEARDOWN_PREVM_QUERY_ARG(2U));
                if (td >= 0 &&
                    SYS_TEARDOWN_STAGE((unsigned int)td) ==
                    SYS_TEARDOWN_RUN_VM &&
                    SYS_TEARDOWN_IS_EXIT_PREVM((unsigned int)td))
                        break;
                (void)dsys_sleep(4U);
        }
        if (i == 200U)
                fail('7');
        (void)dsys_writechar(1, 'V');
        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,
            SYS_EVENT_ARG(3U, SYS_EVENT_TERM)) != 0)
                fail('8');
        for (i = 0U; i < 300U; ++i) {
                if (dsys_procinfo(3U, &info) == 0 &&
                    info.state == 4UL && info.ppid == 1UL)
                        break;
                (void)dsys_sleep(4U);
        }
        if (i == 300U)
                fail('9');
        td = dsys_procctl(SYS_PROCCTL_GETTEARDOWN,
            SYS_TEARDOWN_PREVM_QUERY_ARG(2U));
        if (td < 0 || SYS_TEARDOWN_STAGE((unsigned int)td) !=
            SYS_TEARDOWN_RUN_VM)
                fail('a');
        (void)dsys_writechar(1, 'A');
        status = 0UL;
        if (dsys_wait(3U, &status, 0U) != 3)
                fail('b');
        /* PID2 is still the physical MM owner at adoption time.
         * Wait for the original provider to release it normally. */
        for (i = 0U; i < 4000U; ++i) {
                if (dsys_procinfo(2U, &info) == 0 &&
                    info.state == 4UL)
                        break;
                (void)dsys_sleep(4U);
        }
        if (i == 4000U)
                fail('d');
        status = 0UL;
        if (dsys_wait(2U, &status, 0U) != 2)
                fail('e');
        if (dsys_close(parent_wr) != 0 ||
            dsys_close(child_wr) != 0 ||
            dsys_meminfo(&after) != 0 ||
            after.process_slots_used != before.process_slots_used ||
            after.process_words != before.process_words ||
            after.file_slots_used != before.file_slots_used)
                fail('f');
        (void)dsys_writechar(1, 'P');
        (void)dsys_halt();
        return 0;
}
