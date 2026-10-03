#include "dsys.h"

static void
put_text(const char *s)
{
        while (*s != 0) {
                (void)dsys_writechar(1, (unsigned char)*s);
                ++s;
        }
        (void)dsys_writechar(1, '\r');
        (void)dsys_writechar(1, '\n');
}

static void
fail(unsigned int status)
{
        (void)dsys_writechar(1, 'F');
        (void)dsys_writechar(1, 'G');
        (void)dsys_writechar(1, 'F');
        (void)dsys_writechar(1, 'A');
        (void)dsys_writechar(1, 'I');
        (void)dsys_writechar(1, 'L');
        (void)dsys_writechar(1, '0' + (int)(status & 07U));
        (void)dsys_writechar(1, '\r');
        (void)dsys_writechar(1, '\n');
        (void)dsys_exit((int)status);
}

int
main(void)
{
        int pgrp;

        pgrp = dsys_procctl(SYS_PROCCTL_GETPGRP, 0U);
        if (pgrp <= 0 ||
            dsys_procctl(SYS_PROCCTL_TTY_GETFG, 0U) != pgrp)
                fail(1U);

        /* Deliberately leave the foreground job in RAW mode when it stops.
         * DSH must save this terminal-global state before reclaiming the TTY. */
        if (dsys_procctl(SYS_PROCCTL_TTY_SETMODE, SYS_TTY_MODE_RAW) !=
            (int)SYS_TTY_MODE_RAW ||
            dsys_procctl(SYS_PROCCTL_EVENT_PGRP,
            SYS_EVENT_ARG((unsigned int)pgrp, SYS_EVENT_TSTP)) != 0)
                fail(2U);

        /* Execution resumes here after the first FG/CONT. */
        if (dsys_procctl(SYS_PROCCTL_TTY_GETFG, 0U) != pgrp)
                fail(3U);
        if (dsys_procctl(SYS_PROCCTL_TTY_GETMODE, 0U) !=
            (int)SYS_TTY_MODE_RAW)
                fail(6U);
        put_text("FGRAWOK");

        /* Stop a second time in COOKED mode.  This proves DSH refreshes the
         * saved mode at every foreground stop rather than only at launch. */
        if (dsys_procctl(SYS_PROCCTL_TTY_SETMODE, SYS_TTY_MODE_COOKED) !=
            (int)SYS_TTY_MODE_COOKED ||
            dsys_procctl(SYS_PROCCTL_EVENT_PGRP,
            SYS_EVENT_ARG((unsigned int)pgrp, SYS_EVENT_TSTP)) != 0)
                fail(4U);

        /* Execution resumes here after the second FG/CONT. */
        if (dsys_procctl(SYS_PROCCTL_TTY_GETFG, 0U) != pgrp)
                fail(5U);
        if (dsys_procctl(SYS_PROCCTL_TTY_GETMODE, 0U) !=
            (int)SYS_TTY_MODE_COOKED)
                fail(7U);
        put_text("FGCOOKEDOK");
        (void)dsys_exit(0);
        return 0;
}
