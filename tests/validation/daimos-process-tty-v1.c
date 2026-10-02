#include "dsys.h"
#include "../test_sixbit.h"

#define BGREAD_MODE          0401U
#define OTHER_SESSION_MODE   0402U
#define OTHER_STATUS         071U

#define RUN_PATH_WORDS       3U
#define RUN_ARG_WORDS        2U
#define RUN_PATH_OFF         SYS_RUN_V2_FIXED_WORDS
#define RUN_ARG0_OFF         (RUN_PATH_OFF + RUN_PATH_WORDS)
#define RUN_ARG1_OFF         (RUN_ARG0_OFF + RUN_PATH_WORDS)
#define RUN_MAP_OFF          (RUN_ARG1_OFF + RUN_ARG_WORDS)
#define RUN_BLOCK_WORDS      (RUN_MAP_OFF + 3U)

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

static void
fail(int ch, int rc)
{
        (void)mark('!');
        (void)mark(ch);
        (void)dsys_exit(rc);
}

static int
spawn(unsigned int mode, unsigned int pgrp_mode, unsigned int pgrp)
{
        kword_t block[RUN_BLOCK_WORDS];
        struct sys_run_v2 *run;
        unsigned int i;
        int mode_ch;

        for (i = 0U; i < RUN_BLOCK_WORDS; ++i)
                block[i] = 0UL;
        run = (struct sys_run_v2 *)block;
        run->flags = (kword_t)pgrp_mode;
        run->pgrp = (kword_t)pgrp;
        run->fdmap_count = 3UL;
        run->argc = 2UL;
        run->envc = 0UL;
        for (i = 0U; i < RUN_PATH_WORDS; ++i) {
                block[RUN_PATH_OFF + i] = init_path[i];
                block[RUN_ARG0_OFF + i] = init_path[i];
        }
        mode_ch = mode == BGREAD_MODE ? 'B' : 'O';
        block[RUN_ARG1_OFF] = 1UL;
        block[RUN_ARG1_OFF + 1U] =
            TEST_SIX6(mode_ch, ' ', ' ', ' ', ' ', ' ');
        block[RUN_MAP_OFF] = SYS_RUN_FD_MAP(0U, 0U);
        block[RUN_MAP_OFF + 1U] = SYS_RUN_FD_MAP(1U, 1U);
        block[RUN_MAP_OFF + 2U] = SYS_RUN_FD_MAP(2U, 2U);
        run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
            RUN_BLOCK_WORDS);
        return dsys_run(run);
}

static unsigned int
startup_mode(int argc, kword_t **argv)
{
        unsigned int ch;

        if (argc == 1)
                return 1U;
        if (argc != 2 || argv == 0 || argv[1] == 0 ||
            (argv[1][0] & 0777777UL) != 1UL)
                return 0U;
        ch = (unsigned int)(((argv[1][1] >> 30U) & 077UL) + 040U);
        if (ch == 'B')
                return BGREAD_MODE;
        if (ch == 'O')
                return OTHER_SESSION_MODE;
        return 0U;
}

static int
send_group(unsigned int pgrp, unsigned int event)
{
        return dsys_procctl(SYS_PROCCTL_EVENT_PGRP,
            SYS_EVENT_ARG(pgrp, event));
}

static int
wait_is(unsigned int pid, unsigned int kind, unsigned int value)
{
        kword_t status;
        int got;

        got = dsys_wait(pid, &status, 0U);
        return got == (int)pid && SYS_WAIT_STATUS_KIND(status) == kind &&
            SYS_WAIT_STATUS_VALUE(status) == value ? 0 : -1;
}

int
main(int argc, kword_t **argv)
{
        kword_t status;
        int got;
        int pid;
        unsigned int pgrp;
        unsigned int mode;

        mode = startup_mode(argc, argv);

        if (mode == BGREAD_MODE) {
                pid = dsys_getpid();
                if (pid <= 1 || dsys_procctl(SYS_PROCCTL_GETPGRP, 0U) != pid ||
                    dsys_procctl(SYS_PROCCTL_GETSESSION, 0U) != 1 ||
                    dsys_procctl(SYS_PROCCTL_TTY_GETFG, 0U) != 1)
                        (void)dsys_exit(071);
                if (dsys_procctl(SYS_PROCCTL_GETTTY, 0U) !=
                    (int)SYS_TTY_ATTACHED(0U))
                        (void)dsys_exit(072);
                (void)mark('b');
                /* The first call stops this background group before input.
                 * Later foreground transfers resume the same blocked read. */
                (void)dsys_readchar(0);
                (void)dsys_exit(073);
                return 073;
        }
        if (mode == OTHER_SESSION_MODE) {
                pid = dsys_getpid();
                if (pid <= 1)
                        (void)dsys_exit(074);
                if (dsys_procctl(SYS_PROCCTL_NEWSESSION, 0U) != pid) {
                        (void)mark('n');
                        (void)dsys_exit(075);
                }
                if (dsys_procctl(SYS_PROCCTL_GETTTY, 0U) != SYS_TTY_NO_TTY) {
                        (void)mark('t');
                        (void)dsys_exit(076);
                }
                if (dsys_procctl(SYS_PROCCTL_TTY_ATTACH, 0U) != -1) {
                        (void)mark('a');
                        (void)dsys_exit(077);
                }
                (void)dsys_exit(OTHER_STATUS);
                return OTHER_STATUS;
        }

        if (mode != 1U || dsys_getpid() != 1)
                fail('0', 010);
        if (dsys_procctl(SYS_PROCCTL_GETTTY, 0U) != SYS_TTY_NO_TTY ||
            dsys_procctl(SYS_PROCCTL_TTY_ATTACH, SYS_TTY_ID_MAX + 1U) != -1 ||
            dsys_procctl(SYS_PROCCTL_TTY_ATTACH, 0U) != 0 ||
            dsys_procctl(SYS_PROCCTL_GETTTY, 0U) !=
            (int)SYS_TTY_ATTACHED(0U) ||
            dsys_procctl(SYS_PROCCTL_TTY_GETFG, 0U) != 1)
                fail('1', 011);
        if (mark('<') != 0)
                fail('2', 012);

        pid = spawn(OTHER_SESSION_MODE, SYS_RUN_PGRP_NEW, 0U);
        if (pid <= 1)
                fail('3', 013);
        status = 0UL;
        got = dsys_wait((unsigned int)pid, &status, 0U);
        if (got != pid)
                fail('d', 013);
        if (SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED)
                fail('e', 013);
        if (SYS_WAIT_STATUS_VALUE(status) == 074U)
                fail('p', 013);
        if (SYS_WAIT_STATUS_VALUE(status) == 075U)
                fail('n', 013);
        if (SYS_WAIT_STATUS_VALUE(status) == 076U)
                fail('t', 013);
        if (SYS_WAIT_STATUS_VALUE(status) == 077U)
                fail('a', 013);
        if (SYS_WAIT_STATUS_VALUE(status) != OTHER_STATUS) {
                unsigned int value;

                value = SYS_WAIT_STATUS_VALUE(status);
                (void)mark('0' + ((value >> 15U) & 07U));
                (void)mark('0' + ((value >> 12U) & 07U));
                (void)mark('0' + ((value >> 9U) & 07U));
                (void)mark('0' + ((value >> 6U) & 07U));
                (void)mark('0' + ((value >> 3U) & 07U));
                (void)mark('0' + (value & 07U));
                fail('v', 013);
        }

        pid = spawn(BGREAD_MODE, SYS_RUN_PGRP_NEW, 0U);
        if (pid <= 1)
                fail('4', 014);
        pgrp = (unsigned int)pid;
        if (wait_is((unsigned int)pid, SYS_WAIT_STOPPED,
            SYS_EVENT_TSTP) != 0)
                fail('5', 015);
        (void)mark('1');

        /* CONT alone is BG: the resumed read must stop again because the
         * shell group still owns the terminal. */
        if (send_group(pgrp, SYS_EVENT_CONT) != 0 ||
            wait_is((unsigned int)pid, SYS_WAIT_CONTINUED,
            SYS_EVENT_CONT) != 0 ||
            wait_is((unsigned int)pid, SYS_WAIT_STOPPED,
            SYS_EVENT_TSTP) != 0)
                fail('6', 016);
        (void)mark('2');

        /* FG then Ctrl-Z.  Do not expose the host input marker until the
         * child has actually resumed into its pending terminal read. */
        if (dsys_procctl(SYS_PROCCTL_TTY_SETFG, pgrp) != (int)pgrp ||
            dsys_procctl(SYS_PROCCTL_TTY_GETFG, 0U) != (int)pgrp ||
            send_group(pgrp, SYS_EVENT_CONT) != 0 ||
            wait_is((unsigned int)pid, SYS_WAIT_CONTINUED,
            SYS_EVENT_CONT) != 0)
                fail('7', 017);
        (void)mark('Z');
        if (wait_is((unsigned int)pid, SYS_WAIT_STOPPED,
            SYS_EVENT_TSTP) != 0)
                fail('8', 020);
        (void)mark('3');

        /* BG after Ctrl-Z: ownership first returns to the shell; CONT must
         * again stop at the pending read without consuming terminal input. */
        if (dsys_procctl(SYS_PROCCTL_TTY_SETFG, 1U) != 1 ||
            send_group(pgrp, SYS_EVENT_CONT) != 0 ||
            wait_is((unsigned int)pid, SYS_WAIT_CONTINUED,
            SYS_EVENT_CONT) != 0 ||
            wait_is((unsigned int)pid, SYS_WAIT_STOPPED,
            SYS_EVENT_TSTP) != 0)
                fail('9', 021);
        (void)mark('4');

        /* FG then Ctrl-C.  As above, the marker means the foreground
         * child is resumed and blocked in the terminal read. */
        if (dsys_procctl(SYS_PROCCTL_TTY_SETFG, pgrp) != (int)pgrp ||
            send_group(pgrp, SYS_EVENT_CONT) != 0 ||
            wait_is((unsigned int)pid, SYS_WAIT_CONTINUED,
            SYS_EVENT_CONT) != 0)
                fail('A', 022);
        (void)mark('C');
        if (wait_is((unsigned int)pid, SYS_WAIT_EXITED,
            SYS_WAIT_EVENT_FLAG | SYS_EVENT_INT) != 0)
                fail('B', 023);

        if (dsys_procctl(SYS_PROCCTL_TTY_SETFG, 1U) != 1 ||
            dsys_procctl(SYS_PROCCTL_TTY_SETFG, 077U) != -1 ||
            dsys_procctl(SYS_PROCCTL_TTY_DETACH, 0U) != 0 ||
            dsys_procctl(SYS_PROCCTL_GETTTY, 0U) != SYS_TTY_DETACHED ||
            dsys_procctl(SYS_PROCCTL_TTY_GETFG, 0U) != -1 ||
            dsys_procctl(SYS_PROCCTL_TTY_ATTACH, 0U) != 0 ||
            dsys_procctl(SYS_PROCCTL_TTY_GETFG, 0U) != 1)
                fail('C', 024);

        (void)mark('H');
        (void)dsys_exit(0);
        return 0;
}
