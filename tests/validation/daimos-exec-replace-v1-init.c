#include "u.h"

static kword_t path_dsh[U_PATH_WORDS];
static kword_t path_temp[U_PATH_WORDS];

static void
fail(void)
{
        (void)dsys_writechar(1, '!');
        (void)dsys_halt();
        for (;;) { }
}

int
main(void)
{
        kword_t exec_block[SYS_EXEC_V1_FIXED_WORDS + 2U * U_PATH_WORDS];
        struct sys_exec_v1 *exec;
        unsigned int path_words;
        unsigned int total;
        unsigned int i;
        if (dsys_getpid() != 1)
                fail();
        if (dsys_procctl(SYS_PROCCTL_TTY_ATTACH, 0U) != 0)
                fail();
        if (dsys_procctl(SYS_PROCCTL_TTY_SETFG, 1U) != 1)
                fail();
        if (u_s6_pack(path_temp, U_PATH_WORDS, "/TEMP") != 0)
                fail();
        if (dsys_chdir(path_temp) != 0)
                fail();
        if (dsys_procctl(SYS_PROCCTL_SETGID, 7U) != 7)
                fail();
        if (dsys_procctl(SYS_PROCCTL_SETUID, 6U) != 6)
                fail();
        if (u_s6_pack(path_dsh, U_PATH_WORDS, "/SYSTEM/EXEC/DSH") != 0)
                fail();
        path_words = 1U + ((unsigned int)path_dsh[0] + 5U) / 6U;
        total = SYS_EXEC_V1_FIXED_WORDS;
        for (i = 0U; i < path_words; ++i)
                exec_block[total++] = path_dsh[i];
        for (i = 0U; i < path_words; ++i)
                exec_block[total++] = path_dsh[i];
        exec = (struct sys_exec_v1 *)exec_block;
        exec->version_words = SYS_RUN_HEADER(SYS_EXEC_VERSION_1, total);
        exec->argc = 1UL;
        exec->envc = 0UL;
        (void)dsys_writechar(1, '<');
        (void)dsys_exec(exec);
        fail();
        return 1;
}
