#include "dsys.h"
#include "../test_sixbit.h"

#define SPIN_MODE           0301U
#define EVENT_MODE          0302U
#define SPIN2_MODE          0303U
#define TERM_MODE           0304U
#define HUP_MODE            0305U
#define SELFSTOP_MODE       0306U
#define EVENT_STATUS        061U

#define RUN_PATH_WORDS      3U
#define RUN_ARG_WORDS       2U
#define RUN_PATH_OFF        SYS_RUN_V2_FIXED_WORDS
#define RUN_ARG0_OFF        (RUN_PATH_OFF + RUN_PATH_WORDS)
#define RUN_ARG1_OFF        (RUN_ARG0_OFF + RUN_PATH_WORDS)
#define RUN_MAP_OFF         (RUN_ARG1_OFF + RUN_ARG_WORDS)
#define RUN_BLOCK_WORDS     (RUN_MAP_OFF + 3U)

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
        if (mode == SPIN_MODE)
                mode_ch = 'S';
        else if (mode == EVENT_MODE)
                mode_ch = 'E';
        else if (mode == SPIN2_MODE)
                mode_ch = '2';
        else if (mode == TERM_MODE)
                mode_ch = 'T';
        else if (mode == SELFSTOP_MODE)
                mode_ch = 'X';
        else
                mode_ch = 'H';
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
        if (ch == 'S')
                return SPIN_MODE;
        if (ch == 'E')
                return EVENT_MODE;
        if (ch == '2')
                return SPIN2_MODE;
        if (ch == 'T')
                return TERM_MODE;
        if (ch == 'X')
                return SELFSTOP_MODE;
        if (ch == 'H')
                return HUP_MODE;
        return 0U;
}

static int
send_pid(unsigned int pid, unsigned int event)
{
        return dsys_procctl(SYS_PROCCTL_EVENT_PID,
            SYS_EVENT_ARG(pid, event));
}

static int
send_group(unsigned int pgrp, unsigned int event)
{
        return dsys_procctl(SYS_PROCCTL_EVENT_PGRP,
            SYS_EVENT_ARG(pgrp, event));
}

static int
status_is(kword_t status, unsigned int kind, unsigned int value)
{
        return SYS_WAIT_STATUS_KIND(status) == kind &&
            SYS_WAIT_STATUS_VALUE(status) == value;
}

static int
wait_group_pair(unsigned int pgrp, unsigned int kind, unsigned int value,
    unsigned int a, unsigned int b)
{
        kword_t status;
        unsigned int seen;
        int got;
        unsigned int i;

        seen = 0U;
        for (i = 0U; i < 2U; ++i) {
                got = dsys_wait(SYS_WAIT_PGRP_FLAG | pgrp, &status, 0U);
                if (!status_is(status, kind, value))
                        return -1;
                if (got == (int)a)
                        seen |= 1U;
                else if (got == (int)b)
                        seen |= 2U;
                else
                        return -1;
        }
        return seen == 3U ? 0 : -1;
}

int
main(int argc, kword_t **argv)
{
        struct sys_procinfo info;
        struct sys_meminfo mem;
        kword_t status;
        unsigned int events;
        unsigned int pgrp;
        int a;
        int b;
        int pid;
        volatile kword_t spin;
        unsigned int mode;

        mode = startup_mode(argc, argv);

        if (mode == SPIN_MODE || mode == SPIN2_MODE || mode == TERM_MODE ||
            mode == HUP_MODE) {
                spin = 0UL;
                for (;;)
                        spin += 1UL;
        }
        if (mode == EVENT_MODE) {
                for (;;) {
                        events = (unsigned int)dsys_procctl(
                            SYS_PROCCTL_GETEVENTS, 0U);
                        if ((events & SYS_EVENT_BIT(SYS_EVENT_ALRM)) != 0U)
                                (void)dsys_exit(EVENT_STATUS);
                }
        }
        if (mode == SELFSTOP_MODE) {
                pgrp = (unsigned int)dsys_procctl(SYS_PROCCTL_GETPGRP, 0U);
                if (pgrp == 0U || send_group(pgrp, SYS_EVENT_TSTP) != 0)
                        (void)dsys_exit(071);
                spin = 0UL;
                for (;;)
                        spin += 1UL;
        }

        if (mode != 1U || dsys_getpid() != 1)
                fail('0', 010);
        if (mark('<') != 0)
                fail('1', 011);

        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,
            SYS_EVENT_ARG(077U, SYS_EVENT_TERM)) != -1 ||
            dsys_procctl(SYS_PROCCTL_EVENT_PID,
            SYS_EVENT_ARG(1U, SYS_EVENT_CHLD)) != -1 ||
            dsys_procctl(SYS_PROCCTL_EVENT_PID,
            SYS_EVENT_ARG(1U, SYS_EVENT_TERM) | 010000U) != -1)
                fail('2', 012);

        a = spawn(SPIN_MODE, SYS_RUN_PGRP_NEW, 0U);
        if (a <= 1)
                fail('3', 013);
        pgrp = (unsigned int)a;
        b = spawn(SPIN2_MODE, SYS_RUN_PGRP_JOIN, pgrp);
        if (b <= a)
                fail('4', 014);

        if (send_group(pgrp, SYS_EVENT_TSTP) != 0 ||
            wait_group_pair(pgrp, SYS_WAIT_STOPPED, SYS_EVENT_TSTP,
            (unsigned int)a, (unsigned int)b) != 0)
                fail('5', 015);
        if (dsys_procinfo((unsigned int)a, &info) != 0 || info.state != 6UL ||
            dsys_procinfo((unsigned int)b, &info) != 0 || info.state != 6UL)
                fail('6', 016);
        events = (unsigned int)dsys_procctl(SYS_PROCCTL_GETEVENTS, 0U);
        if ((events & SYS_EVENT_BIT(SYS_EVENT_CHLD)) == 0U)
                fail('7', 017);

        if (send_group(pgrp, SYS_EVENT_CONT) != 0 ||
            wait_group_pair(pgrp, SYS_WAIT_CONTINUED, SYS_EVENT_CONT,
            (unsigned int)a, (unsigned int)b) != 0)
                fail('8', 020);
        events = (unsigned int)dsys_procctl(SYS_PROCCTL_GETEVENTS, 0U);
        if ((events & SYS_EVENT_BIT(SYS_EVENT_CHLD)) == 0U)
                fail('9', 021);

        if (send_group(pgrp, SYS_EVENT_INT) != 0 ||
            wait_group_pair(pgrp, SYS_WAIT_EXITED,
            SYS_WAIT_EVENT_FLAG | SYS_EVENT_INT, (unsigned int)a,
            (unsigned int)b) != 0)
                fail('A', 022);
        events = (unsigned int)dsys_procctl(SYS_PROCCTL_GETEVENTS, 0U);
        if ((events & SYS_EVENT_BIT(SYS_EVENT_CHLD)) == 0U)
                fail('B', 023);

        pid = spawn(SELFSTOP_MODE, SYS_RUN_PGRP_NEW, 0U);
        if (pid <= 1 || dsys_wait((unsigned int)pid, &status, 0U) != pid ||
            !status_is(status, SYS_WAIT_STOPPED, SYS_EVENT_TSTP))
                fail('G', 030);
        if (send_group((unsigned int)pid, SYS_EVENT_CONT) != 0 ||
            dsys_wait((unsigned int)pid, &status, 0U) != pid ||
            !status_is(status, SYS_WAIT_CONTINUED, SYS_EVENT_CONT) ||
            send_group((unsigned int)pid, SYS_EVENT_TERM) != 0 ||
            dsys_wait((unsigned int)pid, &status, 0U) != pid ||
            !status_is(status, SYS_WAIT_EXITED,
            SYS_WAIT_EVENT_FLAG | SYS_EVENT_TERM))
                fail('H', 031);

        pid = spawn(TERM_MODE, SYS_RUN_PGRP_INHERIT, 0U);
        if (pid <= 1 || send_pid((unsigned int)pid, SYS_EVENT_TERM) != 0 ||
            dsys_wait((unsigned int)pid, &status, 0U) != pid ||
            !status_is(status, SYS_WAIT_EXITED,
            SYS_WAIT_EVENT_FLAG | SYS_EVENT_TERM))
                fail('C', 024);

        pid = spawn(HUP_MODE, SYS_RUN_PGRP_INHERIT, 0U);
        if (pid <= 1 || send_pid((unsigned int)pid, SYS_EVENT_HUP) != 0 ||
            dsys_wait((unsigned int)pid, &status, 0U) != pid ||
            !status_is(status, SYS_WAIT_EXITED,
            SYS_WAIT_EVENT_FLAG | SYS_EVENT_HUP))
                fail('D', 025);

        pid = spawn(EVENT_MODE, SYS_RUN_PGRP_INHERIT, 0U);
        if (pid <= 1 || send_pid((unsigned int)pid, SYS_EVENT_ALRM) != 0 ||
            dsys_wait((unsigned int)pid, &status, 0U) != pid ||
            !status_is(status, SYS_WAIT_EXITED, EVENT_STATUS))
                fail('E', 026);

        if (dsys_meminfo(&mem) != 0 || mem.process_slots_used != 2UL)
                fail('F', 027);
        (void)mark('E');
        (void)dsys_exit(0);
        return 0;
}
