/* Full guest: real EXEC destroys old VM, then loader rejects replacement. */
#include "dsys.h"
#include "../test_sixbit.h"

#define EXEC_BLOCK_WORDS   (SYS_EXEC_V1_FIXED_WORDS + RUN_PATH_WORDS)
#define RUN_PATH_WORDS     3U
#define RUN_ARG_WORDS      2U
#define RUN_PATH_OFF       SYS_RUN_V2_FIXED_WORDS
#define RUN_ARG0_OFF       (RUN_PATH_OFF + RUN_PATH_WORDS)
#define RUN_ARG1_OFF       (RUN_ARG0_OFF + RUN_PATH_WORDS)
#define RUN_MAP_OFF        (RUN_ARG1_OFF + RUN_ARG_WORDS)
#define RUN_BLOCK_WORDS    (RUN_MAP_OFF + 3U)

static kword_t init_path[] = {
        12UL,
        TEST_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
        TEST_SIX6('M', '/', 'I', 'N', 'I', 'T')
};

static void
fail(int ch)
{
        (void)dsys_writechar(1, '!');
        (void)dsys_writechar(1, ch);
        (void)dsys_exit(0200);
}

static int
exec_self_v890(void)
{
        kword_t block[EXEC_BLOCK_WORDS];
        struct sys_exec_v1 *req;
        unsigned int i;

        for (i = 0U; i < EXEC_BLOCK_WORDS; ++i)
                block[i] = 0UL;
        req = (struct sys_exec_v1 *)block;
        req->version_words =
            SYS_RUN_HEADER(SYS_EXEC_VERSION_1, EXEC_BLOCK_WORDS);
        req->argc = 0UL;
        req->envc = 0UL;
        for (i = 0U; i < RUN_PATH_WORDS; ++i)
                block[SYS_EXEC_V1_FIXED_WORDS + i] = init_path[i];
        return dsys_exec(req);
}

static int
spawn_exec(void)
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
        block[RUN_ARG1_OFF + 1U] =
            TEST_SIX6('E', ' ', ' ', ' ', ' ', ' ');
        for (i = 0U; i < 3U; ++i)
                block[RUN_MAP_OFF + i] = SYS_RUN_FD_MAP(i, i);
        run->version_words =
            SYS_RUN_HEADER(SYS_RUN_VERSION_2, RUN_BLOCK_WORDS);
        return dsys_run(run);
}

int
main(int argc, kword_t **argv)
{
        kword_t status;
        int child;
        unsigned int mode;

        mode = 0U;
        if (argc == 2 && argv != 0 && argv[1] != 0 &&
            (argv[1][0] & 0777777UL) == 1UL)
                mode = (unsigned int)(((argv[1][1] >> 30U) &
                    077UL) + 040U);
        if (mode == 'E') {
                (void)dsys_writechar(1, 'E');
                /* Valid UUO/EXEC argument; isolated kernel injects
                 * staged memory pressure followed by a failed loader
                 * only AFTER real vm_space_destroy commits. */
                (void)exec_self_v890();
                (void)dsys_writechar(1, '!');
                (void)dsys_exit(0277);
                return 0;
        }
        if (argc != 1 || dsys_getpid() != 1)
                fail('0');
        if (dsys_writechar(1, '<') != 0)
                fail('1');
        child = spawn_exec();
        if (child <= 1)
                fail('2');
        status = 0UL;
        if (dsys_wait((unsigned int)child, &status, 0U) != child)
                fail('3');
        if (SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) != 1U)
                fail('4');
        if (dsys_writechar(1, 'H') != 0)
                fail('5');
        (void)dsys_exit(0);
        return 0;
}
