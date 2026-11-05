#include "dsys.h"
#include "../test_sixbit.h"

#define SPIN_MODE           0301U
#define EVENT_MODE          0302U
#define SPIN2_MODE          0303U
#define TERM_MODE           0304U
#define HUP_MODE            0305U
#define SELFSTOP_MODE       0306U
#define SELFFATAL_MODE      0307U
#define EVENT_STATUS        061U

#ifndef V1155_E08
#define V1155_E08           0
#endif
#if V1155_E08
#define SESSION_MODE        0310U
#define E08_PID_CYCLES      64U
#endif

#define RUN_PATH_WORDS      3U
#define RUN_ARG_WORDS       2U
#define RUN_PATH_OFF        SYS_RUN_V2_FIXED_WORDS
#define RUN_ARG0_OFF        (RUN_PATH_OFF + RUN_PATH_WORDS)
#define RUN_ARG1_OFF        (RUN_ARG0_OFF + RUN_PATH_WORDS)
#define RUN_MAP_OFF         (RUN_ARG1_OFF + RUN_ARG_WORDS)
#define RUN_BLOCK_WORDS     (RUN_MAP_OFF + 3U)

#if V1155_E08
#define E08_SESSION_WORDS   (RUN_MAP_OFF + 4U)
static int send_pid(unsigned int pid, unsigned int event);
static int send_group(unsigned int pgrp, unsigned int event);
static int status_is(kword_t status, unsigned int kind, unsigned int value);
static int wait_group_pair(unsigned int pgrp, unsigned int kind,
    unsigned int value, unsigned int a, unsigned int b);
#endif

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
        else if (mode == SELFFATAL_MODE)
                mode_ch = 'F';
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

#if V1155_E08
/* The fourth FD is a real parent/child publication barrier. The
 * session is fully created before the parent attempts group events. */
static int
spawn_session(int report_fd)
{
        kword_t block[E08_SESSION_WORDS];
        struct sys_run_v2 *run;
        unsigned int i;

        for (i = 0U; i < E08_SESSION_WORDS; ++i)
                block[i] = 0UL;
        run = (struct sys_run_v2 *)block;
        run->flags = SYS_RUN_PGRP_NEW;
        run->fdmap_count = 4UL;
        run->argc = 2UL;
        for (i = 0U; i < RUN_PATH_WORDS; ++i) {
                block[RUN_PATH_OFF + i] = init_path[i];
                block[RUN_ARG0_OFF + i] = init_path[i];
        }
        block[RUN_ARG1_OFF] = 1UL;
        block[RUN_ARG1_OFF + 1U] =
            TEST_SIX6('N', ' ', ' ', ' ', ' ', ' ');
        for (i = 0U; i < 3U; ++i)
                block[RUN_MAP_OFF + i] = SYS_RUN_FD_MAP(i, i);
        block[RUN_MAP_OFF + 3U] = SYS_RUN_FD_MAP(3U,
            (unsigned int)report_fd);
        run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
            E08_SESSION_WORDS);
        return dsys_run(run);
}

static int
spawn_ready_session(void)
{
        kword_t pair;
        kword_t ready;
        int rd;
        int wr;
        int pid;

        pair = dsys_pipe();
        if (pair == ~(kword_t)0UL)
                return -1;
        rd = (int)((pair >> 18U) & 0777777UL);
        wr = (int)(pair & 0777777UL);
        pid = spawn_session(wr);
        if (pid <= 1 || dsys_close(wr) != 0 ||
            dsys_read_words(rd, &ready, 1U) != 1 || ready != 'N' ||
            dsys_close(rd) != 0)
                return -1;
        return pid;
}

static int
no_second_status(unsigned int pid)
{
        kword_t status;
        status = 0UL;
        return dsys_wait(pid, &status, SYS_WAIT_NOHANG) == 0 ? 0 : -1;
}

static int
no_stale_pid(unsigned int pid)
{
        kword_t status;
        status = 0UL;
        return dsys_wait(pid, &status, SYS_WAIT_NOHANG) == -1 &&
            send_pid(pid, SYS_EVENT_TERM) == -1 ? 0 : -1;
}

static int
wait_pid_status(unsigned int pid, unsigned int kind,
    unsigned int value)
{
        kword_t status;
        status = 0UL;
        return dsys_wait(pid, &status, 0U) == (int)pid &&
            status_is(status, kind, value) ? 0 : -1;
}

static int
exercise_e08(void)
{
        struct sys_procinfo info;
        struct sys_meminfo before;
        struct sys_meminfo after;
        unsigned int cycle;
        unsigned int reused;
        unsigned int grp_a;
        unsigned int grp_b;
        unsigned int events;
        int session_a;
        int session_b;
        int a;
        int b;
        int c;
        int d;
        int pid;
        int old_pid;

        if (dsys_meminfo(&before) != 0)
                return -1;
        session_a = spawn_ready_session();
        session_b = spawn_ready_session();
        if (session_a <= 1 || session_b <= session_a)
                return -2;
        (void)mark('a');
        a = spawn(SPIN_MODE, SYS_RUN_PGRP_NEW, 0U);
        b = spawn(SPIN2_MODE, SYS_RUN_PGRP_JOIN, (unsigned int)a);
        c = spawn(SPIN_MODE, SYS_RUN_PGRP_NEW, 0U);
        d = spawn(SPIN2_MODE, SYS_RUN_PGRP_JOIN, (unsigned int)c);
        if (a <= 1 || b <= a || c <= b || d <= c)
                return -3;
        (void)mark('b');
        grp_a = (unsigned int)a;
        grp_b = (unsigned int)c;
        if (send_group(grp_a, SYS_EVENT_TSTP) != 0 ||
            wait_group_pair(grp_a, SYS_WAIT_STOPPED, SYS_EVENT_TSTP,
                (unsigned int)a, (unsigned int)b) != 0 ||
            no_second_status((unsigned int)a) != 0 ||
            no_second_status((unsigned int)b) != 0)
                return -4;
        if (send_group(grp_b, SYS_EVENT_TSTP) != 0 ||
            wait_group_pair(grp_b, SYS_WAIT_STOPPED, SYS_EVENT_TSTP,
                (unsigned int)c, (unsigned int)d) != 0 ||
            no_second_status((unsigned int)c) != 0 ||
            no_second_status((unsigned int)d) != 0)
                return -5;
        if (dsys_procinfo((unsigned int)a, &info) != 0 ||
            info.state != 6UL ||
            dsys_procinfo((unsigned int)d, &info) != 0 ||
            info.state != 6UL ||
            no_second_status((unsigned int)session_a) != 0 ||
            no_second_status((unsigned int)session_b) != 0)
                return -6;
        events = (unsigned int)dsys_procctl(SYS_PROCCTL_GETEVENTS, 0U);
        if ((events & SYS_EVENT_BIT(SYS_EVENT_CHLD)) == 0U)
                return -7;
        (void)mark('c');

        if (send_group(grp_a, SYS_EVENT_CONT) != 0 ||
            wait_group_pair(grp_a, SYS_WAIT_CONTINUED, SYS_EVENT_CONT,
                (unsigned int)a, (unsigned int)b) != 0 ||
            send_group(grp_b, SYS_EVENT_CONT) != 0 ||
            wait_group_pair(grp_b, SYS_WAIT_CONTINUED, SYS_EVENT_CONT,
                (unsigned int)c, (unsigned int)d) != 0 ||
            no_second_status((unsigned int)a) != 0 ||
            no_second_status((unsigned int)d) != 0)
                return -8;
        events = (unsigned int)dsys_procctl(SYS_PROCCTL_GETEVENTS, 0U);
        if ((events & SYS_EVENT_BIT(SYS_EVENT_CHLD)) == 0U)
                return -9;
        (void)mark('d');

        if (send_group(grp_a, SYS_EVENT_TERM) != 0 ||
            wait_group_pair(grp_a, SYS_WAIT_EXITED,
                SYS_WAIT_EVENT_FLAG | SYS_EVENT_TERM,
                (unsigned int)a, (unsigned int)b) != 0 ||
            no_stale_pid((unsigned int)a) != 0 ||
            no_stale_pid((unsigned int)b) != 0 ||
            no_second_status((unsigned int)c) != 0 ||
            no_second_status((unsigned int)d) != 0 ||
            no_second_status((unsigned int)session_a) != 0 ||
            no_second_status((unsigned int)session_b) != 0)
                return -10;
        if (send_group(grp_b, SYS_EVENT_INT) != 0 ||
            wait_group_pair(grp_b, SYS_WAIT_EXITED,
                SYS_WAIT_EVENT_FLAG | SYS_EVENT_INT,
                (unsigned int)c, (unsigned int)d) != 0 ||
            no_stale_pid((unsigned int)c) != 0 ||
            no_stale_pid((unsigned int)d) != 0)
                return -11;
        (void)mark('e');

        reused = 0U;
        old_pid = -1;
        for (cycle = 0U; cycle < E08_PID_CYCLES; ++cycle) {
                pid = spawn(EVENT_MODE, SYS_RUN_PGRP_INHERIT, 0U);
                if (pid <= 1 || pid == session_a || pid == session_b)
                        return -12;
                if (old_pid == pid)
                        ++reused;
                if (send_pid((unsigned int)pid, SYS_EVENT_ALRM) != 0 ||
                    wait_pid_status((unsigned int)pid, SYS_WAIT_EXITED,
                        EVENT_STATUS) != 0 ||
                    no_stale_pid((unsigned int)pid) != 0 ||
                    no_second_status((unsigned int)session_a) != 0 ||
                    no_second_status((unsigned int)session_b) != 0)
                        return -13;
                old_pid = pid;
        }
        if (reused != E08_PID_CYCLES - 1U)
                return -14;
        (void)mark('f');
        if (send_pid((unsigned int)session_a, SYS_EVENT_TERM) != 0 ||
            wait_pid_status((unsigned int)session_a, SYS_WAIT_EXITED,
                SYS_WAIT_EVENT_FLAG | SYS_EVENT_TERM) != 0 ||
            no_stale_pid((unsigned int)session_a) != 0 ||
            no_second_status((unsigned int)session_b) != 0 ||
            send_pid((unsigned int)session_b, SYS_EVENT_TERM) != 0 ||
            wait_pid_status((unsigned int)session_b, SYS_WAIT_EXITED,
                SYS_WAIT_EVENT_FLAG | SYS_EVENT_TERM) != 0 ||
            no_stale_pid((unsigned int)session_b) != 0)
                return -15;
        (void)mark('g');
        events = (unsigned int)dsys_procctl(SYS_PROCCTL_GETEVENTS, 0U);
        if ((events & SYS_EVENT_BIT(SYS_EVENT_CHLD)) == 0U ||
            dsys_meminfo(&after) != 0 ||
            after.process_slots_used != before.process_slots_used ||
            after.process_words != before.process_words ||
            after.file_slots_used != before.file_slots_used)
                return -16;
        return 0;
}
#endif

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
        if (ch == 'F')
                return SELFFATAL_MODE;
        if (ch == 'H')
                return HUP_MODE;
#if V1155_E08
        if (ch == 'N')
                return SESSION_MODE;
#endif
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
        if (mode == SELFFATAL_MODE) {
                pgrp = (unsigned int)dsys_procctl(SYS_PROCCTL_GETPGRP, 0U);
                if (pgrp == 0U || send_group(pgrp, SYS_EVENT_HUP) != 0)
                        (void)dsys_exit(072);
                /* A successfully delivered fatal event must not return. */
                (void)dsys_exit(073);
        }
        if (mode == SELFSTOP_MODE) {
                pgrp = (unsigned int)dsys_procctl(SYS_PROCCTL_GETPGRP, 0U);
                if (pgrp == 0U || send_group(pgrp, SYS_EVENT_TSTP) != 0)
                        (void)dsys_exit(071);
                spin = 0UL;
                for (;;)
                        spin += 1UL;
        }

#if V1155_E08
        if (mode == SESSION_MODE) {
                kword_t ready;
                int me;

                me = dsys_getpid();
                if (me <= 1 ||
                    dsys_procctl(SYS_PROCCTL_NEWSESSION, 0U) != me ||
                    dsys_procctl(SYS_PROCCTL_GETSESSION, 0U) != me ||
                    dsys_procctl(SYS_PROCCTL_GETPGRP, 0U) != me)
                        (void)dsys_exit(075);
                ready = 'N';
                if (dsys_write_words(3, &ready, 1U) != 1 ||
                    dsys_close(3) != 0)
                        (void)dsys_exit(076);
                spin = 0UL;
                for (;;)
                        spin += 1UL;
        }
#endif

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

        pid = spawn(SELFFATAL_MODE, SYS_RUN_PGRP_NEW, 0U);
        if (pid <= 1 || dsys_wait((unsigned int)pid, &status, 0U) != pid ||
            !status_is(status, SYS_WAIT_EXITED,
            SYS_WAIT_EVENT_FLAG | SYS_EVENT_HUP))
                fail('F', 034);

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
#if V1155_E08
        (void)mark('0');
        if (exercise_e08() != 0)
                fail('J', 035);
        if (mark('J') != 0)
                fail('J', 036);
#endif
        (void)mark('E');
        (void)dsys_exit(0);
        return 0;
}
