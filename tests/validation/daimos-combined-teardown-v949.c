/* Booted PDP-6: D6FS SYNC and MM free refuse during
 * deferred TERM closure, then succeeds. All injection is disposable.
 */
#include "dsys.h"
#include "../test_sixbit.h"

#define RUN_PATH_WORDS 3U
#define RUN_ARG_WORDS 2U
#define RUN_PATH_OFF SYS_RUN_V2_FIXED_WORDS
#define RUN_ARG0_OFF (RUN_PATH_OFF + RUN_PATH_WORDS)
#define RUN_ARG1_OFF (RUN_ARG0_OFF + RUN_PATH_WORDS)
#define RUN_MAP_OFF (RUN_ARG1_OFF + RUN_ARG_WORDS)
#define RUN_BLOCK_WORDS (RUN_MAP_OFF + 3U)

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
        (void)dsys_exit(0200);
        for (;;) { }
}

static int
spawn_mode(char mode)
{
        kword_t block[RUN_BLOCK_WORDS];
        struct sys_run_v2 *run;
        unsigned int i;

        for (i = 0U; i < RUN_BLOCK_WORDS; ++i)
                block[i] = 0UL;
        run = (struct sys_run_v2 *)block;
        run->flags = SYS_RUN_PGRP_NEW;
        run->argc = 2UL;
        run->fdmap_count = 3UL;
        for (i = 0U; i < RUN_PATH_WORDS; ++i) {
                block[RUN_PATH_OFF + i] = init_path[i];
                block[RUN_ARG0_OFF + i] = init_path[i];
        }
        block[RUN_ARG1_OFF] = 1UL;
        if (mode == 'S')
                block[RUN_ARG1_OFF + 1U] =
                    TEST_SIX6('S', ' ', ' ', ' ', ' ', ' ');
        else if (mode == 'H')
                block[RUN_ARG1_OFF + 1U] =
                    TEST_SIX6('H', ' ', ' ', ' ', ' ', ' ');
        else if (mode == 'C')
                block[RUN_ARG1_OFF + 1U] =
                    TEST_SIX6('C', ' ', ' ', ' ', ' ', ' ');
        else if (mode == 'D')
                block[RUN_ARG1_OFF + 1U] =
                    TEST_SIX6('D', ' ', ' ', ' ', ' ', ' ');
        else
                block[RUN_ARG1_OFF + 1U] =
                    TEST_SIX6('W', ' ', ' ', ' ', ' ', ' ');
        for (i = 0U; i < 3U; ++i)
                block[RUN_MAP_OFF + i] = SYS_RUN_FD_MAP(i, i);
        run->version_words =
            SYS_RUN_HEADER(SYS_RUN_VERSION_2, RUN_BLOCK_WORDS);
        return dsys_run(run);
}

int
main(int argc, kword_t **argv)
{
        unsigned int mode;
        int spinner;
        int holder;
        int waiter;
        int child_parent;
        int descendant;
        int fd;
        kword_t status;

        mode = 0U;
        if (argc == 2 && argv != 0 && argv[1] != 0 &&
            (argv[1][0] & 0777777UL) == 1UL)
                mode = (unsigned int)(((argv[1][1] >> 30U) &
                    077UL) + 040U);
        if (mode == 'S') {
                for (;;) {
                        if (dsys_sleep(020U) != 0)
                                fail('S');
                        (void)dsys_writechar(1, 'S');
                }
        }
        if (mode == 'H' || mode == 'W') {
                (void)dsys_writechar(1, (int)mode);
                if (dsys_sleep(mode == 'H' ? 020U : 0200U) != 0)
                        fail('T');
                /* H/W remain independent sleepers, leaving the provider
                 * free for the terminating C process's real SYNC calls. */
                for (;;) {
                        if (dsys_sleep(01000U) != 0)
                                fail('R');
                }
        }
        if (mode == 'D') {
                (void)dsys_writechar(1, 'D');
                if (dsys_sleep(01000U) != 0)
                        fail('X');
                /* Distinguish a timer wakeup from an EXIT/CHLD failure. */
                (void)dsys_writechar(1, 'Z');
                (void)dsys_exit(0);
                fail('E');            /* EXIT must not return to user mode. */
        }
        if (mode == 'C') {
                descendant = spawn_mode('D');
                if (descendant != 6)
                        fail('J');
                (void)dsys_writechar(1, 'C');
                /* Hold a real D6FS-root executable descriptor until TERM. */
                fd = dsys_open(init_path, SYS_O_RDONLY);
                if (fd < 0)
                        fail('U');
                status = 0UL;
                if (dsys_wait((unsigned int)descendant, &status, 0U) !=
                    descendant)
                        fail('Y');
                fail('R');
        }
        if (argc != 1 || dsys_getpid() != 1)
                fail('0');
        if (dsys_writechar(1, '<') != 0)
                fail('1');
        spinner = spawn_mode('S');
        holder = spawn_mode('H');
        waiter = spawn_mode('W');
        child_parent = spawn_mode('C');
        if (spinner != 2 || holder != 3 || waiter != 4 ||
            child_parent != 5)
                fail('2');
        /* The test-only kernel arms injection on this first INIT sleep.
         * All three children are already fully created at that point. */
        if (dsys_sleep(0300U) != 0)
                fail('3');
        /* Remote TERM records deferred delivery without releasing any
         * suspended executive stack. The children remain blocked in this
         * test: owner-side completion requires a separate CHLD wakeup test.
         */
        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,
                SYS_EVENT_ARG(holder, SYS_EVENT_TERM)) != 0)
                fail('5');
        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,
                SYS_EVENT_ARG(waiter, SYS_EVENT_TERM)) != 0)
                fail('6');
        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,
                SYS_EVENT_ARG(child_parent, SYS_EVENT_TERM)) != 0)
                fail('7');
        if (dsys_sleep(01000U) != 0)
                fail('8');
        status = 0UL;
        if (dsys_wait((unsigned int)child_parent, &status, 0U) !=
            child_parent)
                fail('9');
        if (status != SYS_WAIT_STATUS(SYS_WAIT_EXITED, 0400001UL)) {
                unsigned int shift;
                (void)dsys_writechar(1, '[');
                for (shift = 15U; shift <= 15U; shift -= 3U)
                        (void)dsys_writechar(1,
                            '0' + (int)((status >> shift) & 7UL));
                (void)dsys_writechar(1, ']');
                fail('A');
        }
        if (dsys_writechar(1, 'P') != 0)
                fail('4');
        /* Test-only kernel halts here, before INIT can tear down children. */
        (void)dsys_exit(0);
        return 0;
}
