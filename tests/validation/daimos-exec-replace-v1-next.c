#include "u.h"

static kword_t cwd[U_PATH_WORDS];

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
        int tty;

        if (dsys_getpid() != 1)
                fail();
        if (dsys_procctl(SYS_PROCCTL_GETPGRP, 0U) != 1)
                fail();
        if (dsys_procctl(SYS_PROCCTL_GETSESSION, 0U) != 1)
                fail();
        tty = dsys_procctl(SYS_PROCCTL_GETTTY, 0U);
        if (tty != (int)SYS_TTY_ATTACHED(0U))
                fail();
        if (dsys_procctl(SYS_PROCCTL_GETUID, 0U) != 6)
                fail();
        if (dsys_procctl(SYS_PROCCTL_GETGID, 0U) != 7)
                fail();
        if (dsys_getcwd(cwd, U_PATH_WORDS) != 0)
                fail();
        if (!u_s6_eq(cwd, "/TEMP"))
                fail();
        if (dsys_writechar(1, 'E') != 0)
                fail();
        (void)dsys_exit(0);
        return 0;
}
