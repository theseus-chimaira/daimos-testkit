#include "u.h"

#define TEST_SIXCHAR(ch) \
        ((unsigned long)(((unsigned int)(ch) - 040U) & 077U))
#define TEST_SIX6(a,b,c,d,e,f) \
        ((TEST_SIXCHAR(a) << 30) | (TEST_SIXCHAR(b) << 24) | \
        (TEST_SIXCHAR(c) << 18) | (TEST_SIXCHAR(d) << 12) | \
        (TEST_SIXCHAR(e) << 6) | TEST_SIXCHAR(f))

#define RUN_PATH_WORDS 3U
#define RUN_ARG_WORDS 2U
#define RUN_PATH_OFF SYS_RUN_V2_FIXED_WORDS
#define RUN_ARG0_OFF (RUN_PATH_OFF + RUN_PATH_WORDS)
#define RUN_ARG1_OFF (RUN_ARG0_OFF + RUN_PATH_WORDS)
#define RUN_MAP_OFF (RUN_ARG1_OFF + RUN_ARG_WORDS)
#define RUN_BLOCK_WORDS (RUN_MAP_OFF + 3U)
#define EXEC_BLOCK_WORDS (SYS_EXEC_V1_FIXED_WORDS + 2U * RUN_PATH_WORDS)

static kword_t init_path[] = {
        12UL,
        TEST_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
        TEST_SIX6('M', '/', 'I', 'N', 'I', 'T')
};

static kword_t child_arg[] = {
        1UL,
        TEST_SIX6('C', ' ', ' ', ' ', ' ', ' ')
};

static void
fail(int ch, int rc)
{
        (void)dsys_writechar(1, '!');
        (void)dsys_writechar(1, ch);
        (void)dsys_exit(rc);
        for (;;) { }
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
        run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
            RUN_BLOCK_WORDS);
        run->flags = SYS_RUN_PGRP_INHERIT;
        run->pgrp = 0UL;
        run->fdmap_count = 3UL;
        run->argc = 2UL;
        run->envc = 0UL;
        for (i = 0U; i < RUN_PATH_WORDS; ++i) {
                block[RUN_PATH_OFF + i] = init_path[i];
                block[RUN_ARG0_OFF + i] = init_path[i];
        }
        for (i = 0U; i < RUN_ARG_WORDS; ++i)
                block[RUN_ARG1_OFF + i] = child_arg[i];
        block[RUN_MAP_OFF] = SYS_RUN_FD_MAP(0U, 0U);
        block[RUN_MAP_OFF + 1U] = SYS_RUN_FD_MAP(1U, 1U);
        block[RUN_MAP_OFF + 2U] = SYS_RUN_FD_MAP(2U, 2U);
        return dsys_run(run);
}

static int
exec_self(void)
{
        kword_t block[EXEC_BLOCK_WORDS];
        struct sys_exec_v1 *exec;
        unsigned int i;

        for (i = 0U; i < EXEC_BLOCK_WORDS; ++i)
                block[i] = 0UL;
        exec = (struct sys_exec_v1 *)block;
        exec->version_words = SYS_RUN_HEADER(SYS_EXEC_VERSION_1,
            EXEC_BLOCK_WORDS);
        exec->argc = 1UL;
        exec->envc = 0UL;
        for (i = 0U; i < RUN_PATH_WORDS; ++i) {
                block[SYS_EXEC_V1_FIXED_WORDS + i] = init_path[i];
                block[SYS_EXEC_V1_FIXED_WORDS + RUN_PATH_WORDS + i] =
                    init_path[i];
        }
        return dsys_exec(exec);
}

int
main(int argc, kword_t **argv)
{
        kword_t status;
        int pid;

        pid = dsys_getpid();
        if (pid <= 0)
                fail('0', 010);

        if (pid > 1 && argc == 1) {
                if (dsys_procctl(SYS_PROCCTL_GETSESSION, 0U) != pid ||
                    dsys_procctl(SYS_PROCCTL_GETPGRP, 0U) != pid ||
                    dsys_procctl(SYS_PROCCTL_GETTTY, 0U) !=
                    (int)SYS_TTY_ATTACHED(0U))
                        fail('1', 011);
                if (dsys_writechar(1, 'E') != 0)
                        fail('2', 012);
                (void)dsys_exit(0);
                return 0;
        }

        if (pid > 1 && argc == 2 && argv != 0 &&
            u_s6_eq(argv[1], "C")) {
                if (dsys_procctl(SYS_PROCCTL_NEWSESSION, 0U) != pid ||
                    dsys_procctl(SYS_PROCCTL_TTY_ATTACH, 0U) != 0 ||
                    dsys_procctl(SYS_PROCCTL_TTY_SETFG,
                    (unsigned int)pid) != pid)
                        fail('3', 013);
                if (dsys_writechar(1, 'x') != 0)
                        fail('4', 014);
                (void)exec_self();
                fail('5', 015);
        }

        if (pid != 1)
                fail('6', 016);
        if (dsys_writechar(1, '<') != 0)
                fail('7', 017);
        pid = spawn_child();
        if (pid <= 1)
                fail('8', 020);
        if (dsys_wait((unsigned int)pid, &status, 0U) != pid ||
            SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) != 0U)
                fail('9', 021);
        if (dsys_writechar(1, 'P') != 0)
                fail('A', 022);
        (void)dsys_exit(0);
        return 0;
}
