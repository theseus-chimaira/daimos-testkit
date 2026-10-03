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

static int
arg_eq(const kword_t *arg, const char *text)
{
        unsigned int len;
        unsigned int i;
        unsigned int wi;
        unsigned int sh;
        int ch;

        if (arg == 0 || text == 0)
                return 0;
        len = (unsigned int)arg[0];
        for (i = 0U; text[i] != 0; ++i)
                ;
        if (i != len)
                return 0;
        for (i = 0U; i < len; ++i) {
                wi = 1U + i / 6U;
                sh = 30U - (i % 6U) * 6U;
                ch = (int)(((arg[wi] >> sh) & 077UL) + 040UL);
                if (ch != (unsigned char)text[i])
                        return 0;
        }
        return 1;
}

int
main(int argc, kword_t **argv)
{
        int pgrp;
        int terminate_group;

        /* A passive first pipeline stage keeps a second process alive in the
         * job while the final DSHFGT instance drives stop/continue checks. */
        if (argc > 1 && arg_eq(argv[1], "HOLD")) {
                for (;;)
                        if (dsys_sleep(60U) != 0)
                                fail(6U);
        }
        terminate_group = argc > 1 && arg_eq(argv[1], "KILL");

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
        if (terminate_group)
                (void)dsys_procctl(SYS_PROCCTL_EVENT_PGRP,
                    SYS_EVENT_ARG((unsigned int)pgrp, SYS_EVENT_TERM));
        (void)dsys_exit(0);
        return 0;
}
