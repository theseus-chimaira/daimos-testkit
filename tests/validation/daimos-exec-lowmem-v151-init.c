/* Target-side PDP-6 integration exercise: exhaust the contiguous user arena
 * using the public BRK ABI, then replace this process with the existing
 * EXEC-v1 successor. No test-only kernel allocation switches are involved.
 */
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
        kword_t block[SYS_EXEC_V1_FIXED_WORDS + 2U * U_PATH_WORDS];
        struct sys_exec_v1 *exec;
        kword_t top, candidate;
        unsigned int n, i;
        int exec_result;

        if (dsys_getpid() != 1 ||
            dsys_procctl(SYS_PROCCTL_TTY_ATTACH, 0U) != 0 ||
            dsys_procctl(SYS_PROCCTL_TTY_SETFG, 1U) != 1)
                fail();
        if (u_s6_pack(path_temp, U_PATH_WORDS, "/TEMP") != 0 ||
            dsys_chdir(path_temp) != 0 ||
            dsys_procctl(SYS_PROCCTL_SETGID, 7U) != 7 ||
            dsys_procctl(SYS_PROCCTL_SETUID, 6U) != 6)
                fail();

        top = dsys_brk(0UL);
        if (top == (kword_t)-1L)
                fail();
        /* The APR grows in 02000-word quanta. Keep one quantum for the
         * temporary kernel-owned EXEC request after exhausting free core.
         */
        for (i = 0; i < 96U; ++i) {
                candidate = top + 02000UL;
                if (dsys_brk(candidate) == (kword_t)-1L)
                        break;
                top = candidate;
        }
        if (i == 96U || i < 6U ||
            dsys_brk(top - 02000UL) == (kword_t)-1L)
                fail();
        (void)u_puts(1, "BRK=");
        (void)u_put_uint(1, top);
        (void)u_puts(1, " STEPS=");
        (void)u_put_uint(1, (kword_t)i);
        (void)dsys_writechar(1, ';');

        if (u_s6_pack(path_dsh, U_PATH_WORDS, "/SYSTEM/EXEC/DSH") != 0)
                fail();
        n = 1U + ((unsigned int)path_dsh[0] + 5U) / 6U;
        for (i = 0; i < n; ++i) {
                block[SYS_EXEC_V1_FIXED_WORDS + i] = path_dsh[i];
                block[SYS_EXEC_V1_FIXED_WORDS + n + i] = path_dsh[i];
        }
        exec = (struct sys_exec_v1 *)block;
        exec->version_words = SYS_RUN_HEADER(SYS_EXEC_VERSION_1,
            SYS_EXEC_V1_FIXED_WORDS + 2U * n);
        exec->argc = 1UL;
        exec->envc = 0UL;
        (void)dsys_writechar(1, '<');
        exec_result = dsys_exec(exec);
        (void)u_puts(1, "EXEC_RETURN=");
        (void)u_put_uint(1, (kword_t)exec_result);
        (void)dsys_writechar(1, ';');
        fail();
        return 1;
}
