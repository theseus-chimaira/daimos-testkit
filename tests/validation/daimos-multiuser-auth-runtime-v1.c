#include "dsys.h"
#include "../test_sixbit.h"

#define RUN_PATH_WORDS      3U
#define RUN_ARG_WORDS       2U
#define RUN_PATH_OFF        SYS_RUN_V2_FIXED_WORDS
#define RUN_ARG0_OFF        (RUN_PATH_OFF + RUN_PATH_WORDS)
#define RUN_ARG1_OFF        (RUN_ARG0_OFF + RUN_PATH_WORDS)
#define RUN_MAP_OFF         (RUN_ARG1_OFF + RUN_ARG_WORDS)
#define RUN_BLOCK_WORDS     (RUN_MAP_OFF + 2U)

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

static int
spawn_child(void)
{
        kword_t block[RUN_BLOCK_WORDS];
        struct sys_run_v2 *run;
        unsigned int i;

        for (i = 0U; i < RUN_BLOCK_WORDS; ++i)
                block[i] = 0UL;
        run = (struct sys_run_v2 *)block;
        run->flags = SYS_RUN_PGRP_INHERIT;
        run->fdmap_count = 2UL;
        run->argc = 2UL;
        for (i = 0U; i < RUN_PATH_WORDS; ++i) {
                block[RUN_PATH_OFF + i] = init_path[i];
                block[RUN_ARG0_OFF + i] = init_path[i];
        }
        block[RUN_ARG1_OFF] = 1UL;
        block[RUN_ARG1_OFF + 1U] = TEST_SIX6('C', ' ', ' ', ' ', ' ', ' ');
        block[RUN_MAP_OFF] = SYS_RUN_FD_MAP(0U, 0U);
        block[RUN_MAP_OFF + 1U] = SYS_RUN_FD_MAP(1U, 1U);
        run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
            RUN_BLOCK_WORDS);
        return dsys_run(run);
}

int
main(int argc, kword_t **argv)
{
        kword_t status;
        int child;

        if (argc == 2) {
                (void)dsys_sleep(12U);
                (void)dsys_exit(0);
                return 0;
        }
        if (argc != 1 || dsys_getpid() != 1)
                (void)dsys_exit(010);
        child = spawn_child();
        if (child <= 1)
                (void)dsys_exit(011);
        if (dsys_procctl(SYS_PROCCTL_SETUID, 1U) != 1)
                (void)dsys_exit(012);
        if (dsys_halt() != -1 ||
            dsys_rtctl(SYS_RTCTL_ENABLE) != -1 ||
            dsys_nice(-20) != -1 ||
            dsys_unmount(init_path) != -1 ||
            dsys_procctl(SYS_PROCCTL_EVENT_PID,
                SYS_EVENT_ARG((unsigned int)child, SYS_EVENT_TERM)) != -1)
                (void)dsys_exit(013);
        if (dsys_wait((unsigned int)child, &status, 0U) != child)
                (void)dsys_exit(014);
        if (mark('P') != 0)
                (void)dsys_exit(015);
        (void)dsys_exit(0);
        return 0;
}
