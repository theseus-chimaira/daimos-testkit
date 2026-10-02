#include "u.h"
#include "../test_sixbit.h"

#define PATH_WORDS 5U
#define RUN_PATH_OFF SYS_RUN_V2_FIXED_WORDS
#define RUN_MAP_OFF (RUN_PATH_OFF + PATH_WORDS)
#define RUN_WORDS (RUN_MAP_OFF + 4U)

static kword_t child_path[PATH_WORDS] = {
        22UL,
        TEST_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
        TEST_SIX6('M', '/', 'E', 'X', 'E', 'C'),
        TEST_SIX6('/', 'T', 'S', 'F', 'S', 'P'),
        TEST_SIX6('R', 'O', 'B', 'E', ' ', ' ')
};

static int
spawn_child(int ready_fd)
{
        kword_t block[RUN_WORDS];
        struct sys_run_v2 *run;
        unsigned int i;

        for (i = 0U; i < RUN_WORDS; ++i)
                block[i] = 0UL;
        run = (struct sys_run_v2 *)block;
        run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2, RUN_WORDS);
        run->flags = SYS_RUN_PGRP_INHERIT;
        run->fdmap_count = 4UL;
        run->argc = 0UL;
        run->envc = 0UL;
        for (i = 0U; i < PATH_WORDS; ++i)
                block[RUN_PATH_OFF + i] = child_path[i];
        block[RUN_MAP_OFF] = SYS_RUN_FD_MAP(0U, 0U);
        block[RUN_MAP_OFF + 1U] = SYS_RUN_FD_MAP(1U, 1U);
        block[RUN_MAP_OFF + 2U] = SYS_RUN_FD_MAP(2U, 2U);
        block[RUN_MAP_OFF + 3U] = SYS_RUN_FD_MAP(3U,
            (unsigned int)ready_fd);
        return dsys_run(run);
}

static int
terminate_wait(int pid)
{
        kword_t status;

        if (pid <= 1)
                return -1;
        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,
            SYS_EVENT_ARG((unsigned int)pid, SYS_EVENT_TERM)) < 0)
                return -1;
        if (dsys_wait((unsigned int)pid, &status, 0U) != pid)
                return -1;
        return 0;
}

int
main(void)
{
        kword_t pair;
        kword_t ready;
        int ready_r;
        int ready_w;
        int first;
        int second;
        int third;

        pair = dsys_pipe();
        if (pair == ~0UL)
                return 1;
        ready_r = (int)((pair >> 18U) & 0777777UL);
        ready_w = (int)(pair & 0777777UL);
        (void)dsys_writechar(1, '<');
        first = spawn_child(ready_w);
        if (first <= 1)
                return 2;
        if (dsys_read_words(ready_r, &ready, 1U) != 1 || ready != (kword_t)'r')
                return 3;
        second = spawn_child(ready_w);
        if (second >= 0)
                return 4;
        (void)dsys_writechar(1, 'B');
        if (terminate_wait(first) != 0)
                return 5;
        third = spawn_child(ready_w);
        if (third <= 1)
                return 6;
        if (dsys_read_words(ready_r, &ready, 1U) != 1 || ready != (kword_t)'r')
                return 7;
        (void)dsys_writechar(1, 'A');
        if (terminate_wait(third) != 0)
                return 8;
        (void)dsys_close(ready_r);
        (void)dsys_close(ready_w);
        (void)dsys_writechar(1, '>');
        return 0;
}
