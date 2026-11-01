/* A rejected RUN startup must release both VM and its allocated u-area.
 * The test kernel rejects the first startup after MM allocation, then lets
 * a second RUN use the same path normally.  All guest code is ANSI C. */
#include "dsys.h"
#include "../test_sixbit.h"

#define PATH_WORDS 3U
#define ARG_WORDS 2U
#define PATH_OFF SYS_RUN_V2_FIXED_WORDS
#define ARG0_OFF (PATH_OFF + PATH_WORDS)
#define ARG1_OFF (ARG0_OFF + PATH_WORDS)
#define MAP_OFF (ARG1_OFF + ARG_WORDS)
#define BLOCK_WORDS (MAP_OFF + 3U)

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
run_child(void)
{
        kword_t block[BLOCK_WORDS];
        struct sys_run_v2 *req;
        unsigned int i;

        for (i = 0U; i < BLOCK_WORDS; ++i)
                block[i] = 0UL;
        req = (struct sys_run_v2 *)block;
        req->flags = SYS_RUN_PGRP_INHERIT;
        req->argc = 2UL;
        req->fdmap_count = 3UL;
        for (i = 0U; i < PATH_WORDS; ++i) {
                block[PATH_OFF + i] = init_path[i];
                block[ARG0_OFF + i] = init_path[i];
        }
        block[ARG1_OFF] = 1UL;
        block[ARG1_OFF + 1U] = TEST_SIX6('E', ' ', ' ', ' ', ' ', ' ');
        block[MAP_OFF] = SYS_RUN_FD_MAP(0U, 0U);
        block[MAP_OFF + 1U] = SYS_RUN_FD_MAP(1U, 1U);
        block[MAP_OFF + 2U] = SYS_RUN_FD_MAP(2U, 2U);
        req->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
            BLOCK_WORDS);
        return dsys_run(req);
}

int
main(int argc, kword_t **argv)
{
        struct sys_meminfo before;
        struct sys_meminfo after;
        kword_t status;
        int pid;

        if (argc == 2 && argv != 0 && argv[1] != 0 &&
            argv[1][0] == 1UL &&
            argv[1][1] == TEST_SIX6('E', ' ', ' ', ' ', ' ', ' ')) {
                (void)dsys_writechar(1, 'B');
                (void)dsys_exit(043);
                return 043;
        }
        if (argc != 1 || dsys_getpid() != 1)
                fail('0');
        if (dsys_meminfo(&before) != 0)
                fail('1');
        (void)dsys_writechar(1, '<');
        if (run_child() != -1)
                fail('2');
        if (dsys_meminfo(&after) != 0 ||
            after.process_slots_used != before.process_slots_used ||
            after.process_words != before.process_words)
                fail('3');
        if (dsys_procctl(SYS_PROCCTL_GETTEARDOWN, 2U) != -1)
                fail('4');
        (void)dsys_writechar(1, 'R');
        pid = run_child();
        if (pid <= 1)
                fail('5');
        if (dsys_wait((unsigned int)pid, &status, 0U) != pid ||
            SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) != 043U)
                fail('6');
        if (dsys_meminfo(&after) != 0 ||
            after.process_slots_used != before.process_slots_used ||
            after.process_words != before.process_words)
                fail('7');
        (void)dsys_writechar(1, 'P');
        (void)dsys_halt();
        return 0;
}
