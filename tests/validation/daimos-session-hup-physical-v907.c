#include "dsys.h"
#include "../test_sixbit.h"

#define LEADER_MODE          0431U
#define JOB_MODE             0432U

#define RUN_PATH_WORDS       3U
#define RUN_ARG_WORDS        2U
#define RUN_PATH_OFF         SYS_RUN_V2_FIXED_WORDS
#define RUN_ARG0_OFF         (RUN_PATH_OFF + RUN_PATH_WORDS)
#define RUN_ARG1_OFF         (RUN_ARG0_OFF + RUN_PATH_WORDS)
#define RUN_MAP_OFF          (RUN_ARG1_OFF + RUN_ARG_WORDS)
#define RUN_BLOCK_WORDS      (RUN_MAP_OFF + 4U)

static volatile kword_t spin_word;

#ifdef DAIMOS_V1105_DPY_HUP
#define V1105_DPY_WORDS 32U
static kword_t v1105_dpy_path[] = {
        9UL,
        TEST_SIX6('/', 'D', 'E', 'V', '/', 'D'),
        TEST_SIX6('P', 'Y', '0', ' ', ' ', ' ')
};
static kword_t v1105_dpy_frame[V1105_DPY_WORDS];
#endif

static kword_t init_path[] = {
        12UL,
        TEST_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
        TEST_SIX6('M', '/', 'I', 'N', 'I', 'T')
};

static int
new_pipe(int *read_fd, int *write_fd)
{
        kword_t pair;

        pair = dsys_pipe();
        if (pair == ~0UL)
                return -1;
        *read_fd = (int)((pair >> 18U) & 0777777UL);
        *write_fd = (int)(pair & 0777777UL);
        return 0;
}

static int
spawn(unsigned int mode, unsigned int pgrp_mode, unsigned int pgrp,
    int report_fd)
{
        kword_t block[RUN_BLOCK_WORDS];
        struct sys_run_v2 *run;
        unsigned int n;
        unsigned int i;
        int mode_ch;

        for (i = 0U; i < RUN_BLOCK_WORDS; ++i)
                block[i] = 0UL;
        run = (struct sys_run_v2 *)block;
        run->flags = (kword_t)pgrp_mode;
        run->pgrp = (kword_t)pgrp;
        run->argc = 2UL;
        run->envc = 0UL;
        for (i = 0U; i < RUN_PATH_WORDS; ++i) {
                block[RUN_PATH_OFF + i] = init_path[i];
                block[RUN_ARG0_OFF + i] = init_path[i];
        }
        mode_ch = mode == LEADER_MODE ? 'L' : 'J';
        block[RUN_ARG1_OFF] = 1UL;
        block[RUN_ARG1_OFF + 1U] =
            TEST_SIX6(mode_ch, ' ', ' ', ' ', ' ', ' ');
        n = 0U;
        block[RUN_MAP_OFF + n++] = SYS_RUN_FD_MAP(0U, 0U);
        block[RUN_MAP_OFF + n++] = SYS_RUN_FD_MAP(1U, 1U);
        block[RUN_MAP_OFF + n++] = SYS_RUN_FD_MAP(2U, 2U);
        if (report_fd >= 0)
                block[RUN_MAP_OFF + n++] = SYS_RUN_FD_MAP(3U,
                    (unsigned int)report_fd);
        run->fdmap_count = (kword_t)n;
        run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
            RUN_MAP_OFF + n);
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
        if (ch == 'L')
                return LEADER_MODE;
        if (ch == 'J')
                return JOB_MODE;
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

        status = 0UL;
        got = dsys_wait(pid, &status, 0U);
        return got == (int)pid && SYS_WAIT_STATUS_KIND(status) == kind &&
            SYS_WAIT_STATUS_VALUE(status) == value ? 0 : -1;
}

static void
fail(int ch, int status)
{
        (void)dsys_writechar(1, '!');
        (void)dsys_writechar(1, ch);
#ifdef DAIMOS_V1107_SWAP_HUP
        /* An unrepaired DISK owner can legitimately prevent EXIT from
         * completing. Halt the diagnostic guest and sample counters. */
        (void)dsys_halt();
#endif
        (void)dsys_exit(status);
}

static int
pipe_recv(int fd, kword_t *word)
{
        return dsys_read_words(fd, word, 1U) == 1 ? 0 : -1;
}

static void
leader_main(void)
{
        kword_t report;
        int pid;
        int job1;
        int job2;

        pid = dsys_getpid();
        if (pid <= 1 || dsys_procctl(SYS_PROCCTL_NEWSESSION, 0U) != pid ||
            dsys_procctl(SYS_PROCCTL_TTY_ATTACH, 0U) != 0 ||
            dsys_procctl(SYS_PROCCTL_TTY_GETFG, 0U) != pid)
                (void)dsys_exit(0101);
        job1 = spawn(JOB_MODE, SYS_RUN_PGRP_NEW, 0U, -1);
        job2 = spawn(JOB_MODE, SYS_RUN_PGRP_NEW, 0U, -1);
        report = (kword_t)job1;
        if (job1 <= 1 || job2 <= 1 ||
            send_group((unsigned int)job1, SYS_EVENT_TSTP) != 0 ||
            wait_is((unsigned int)job1, SYS_WAIT_STOPPED,
            SYS_EVENT_TSTP) != 0 || dsys_write_words(3, &report, 1U) != 1)
                (void)dsys_exit(0102);
        report = (kword_t)job2;
        if (dsys_write_words(3, &report, 1U) != 1)
                (void)dsys_exit(0102);
        /* Parent delivers HUP twice; never EXIT while it is retrying. */
        for (;;)
                spin_word += 1UL;
}

int
main(int argc, kword_t **argv)
{
        kword_t report;
        int report_r;
        int report_w;
        int leader;
        int job1;
        int job2;
        unsigned int mode;

        mode = startup_mode(argc, argv);

        if (mode == JOB_MODE) {
#ifdef DAIMOS_V1104_PIPE_HUP
                /* C89 declarations precede the optional DPY setup. */
                kword_t pipe_pair;
#endif
#ifdef DAIMOS_V1105_DPY_HUP
                if (dsys_getpid() == 4) {
                        unsigned int word;
                        int dpy_fd;

                        for (word = 0U; word < V1105_DPY_WORDS; ++word)
                                v1105_dpy_frame[word] = 0353535353535UL;
                        dpy_fd = dsys_open(v1105_dpy_path, SYS_O_WRONLY);
                        if (dpy_fd < 0 ||
                            dsys_write_words(dpy_fd, v1105_dpy_frame,
                                V1105_DPY_WORDS) != (int)V1105_DPY_WORDS)
                                (void)dsys_exit(0105);
                        /* The published list must remain live until
                         * the remote HUP retires this exact descriptor. */
                }
#endif
#ifdef DAIMOS_V1104_PIPE_HUP
                /* Keep a genuine private PIPE until the parent's remote HUP.
                 * FILE close must not lose its final reference on MM_BUSY. */
                pipe_pair = dsys_pipe();
                if (pipe_pair == ~0UL)
                        (void)dsys_exit(0104);
#endif
                if (dsys_procctl(SYS_PROCCTL_GETTTY, 0U) !=
                    (int)SYS_TTY_ATTACHED(0U))
                        (void)dsys_exit(0103);
                for (;;)
                        spin_word += 1UL;
        }
        if (mode == LEADER_MODE) {
                leader_main();
                return 0;
        }
        if (mode != 1U || dsys_getpid() != 1)
                fail('0', 0200);
        if (dsys_writechar(1, '<') != 0 ||
            dsys_procctl(SYS_PROCCTL_GETTTY, 0U) != SYS_TTY_NO_TTY ||
            new_pipe(&report_r, &report_w) != 0)
                fail('1', 0201);
        leader = spawn(LEADER_MODE, SYS_RUN_PGRP_NEW, 0U, report_w);
        if (leader <= 1 || dsys_close(report_w) != 0)
                fail('2', 0202);
        if (pipe_recv(report_r, &report) != 0)
                fail('3', 0203);
        job1 = (int)report;
        if (pipe_recv(report_r, &report) != 0)
                fail('3', 0203);
        job2 = (int)report;
        if (job1 <= 1 || job2 <= 1 || job1 == job2 ||
            dsys_close(report_r) != 0)
                fail('3', 0203);
#ifdef DAIMOS_V1107_SWAP_HUP
        /* Production INIT enables swap through this privileged syscall.
         * The isolated test INIT must explicitly do the same. */
        if (dsys_storagectl(SYS_STORAGECTL_SWAP) != 0)
                fail('s', 0213);
#endif
#ifdef DAIMOS_V1105_DPY_HUP
        /* Ensure job2 has installed its hardware display program before
         * INIT requests the first fatal session HUP. */
        if (dsys_sleep(020U) != 0)
                fail('d', 0211);
#endif
        /* First HUP fails after a committed child, second retries it. */
        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,
            SYS_EVENT_ARG((unsigned int)leader, SYS_EVENT_HUP)) != -1)
                fail('6', 0206);
#if defined(DAIMOS_V1104_PIPE_HUP) || \
    defined(DAIMOS_V1105_DPY_HUP) || defined(DAIMOS_V1107_SWAP_HUP)
        {
                kword_t pending_status;

                /* INIT directly parents the session leader, not job2.
                 * A rejected PIPE/DPY/swap release must prevent the leader
                 * from becoming waitable before HUP actually commits. */
                pending_status = 0UL;
                if (dsys_wait((unsigned int)leader, &pending_status,
                    SYS_WAIT_NOHANG) != 0)
                        fail('q', 0210);
        }
#endif
#ifdef DAIMOS_V1105_DPY_HUP
        /* PI6/PI7 must be able to replay the original DPY list even
         * after the first physical MM_BUSY. */
        if (dsys_sleep(020U) != 0)
                fail('r', 0212);
#endif
#ifdef DAIMOS_V1107_SWAP_HUP
        /* A failed DISK backing check publishes FINALIZE+PREVM and
         * is repaired through the slot-0 reaper, not by delivering
         * another HUP into a process already in TRANSITION. Wait past
         * the first 16-tick retry interval before the leader's retry. */
        if (dsys_sleep(0200U) != 0)
                fail('r', 0212);
#endif
        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,
            SYS_EVENT_ARG((unsigned int)leader, SYS_EVENT_HUP)) != 0)
                fail('7', 0207);
        if (wait_is((unsigned int)leader, SYS_WAIT_EXITED,
            SYS_WAIT_EVENT_FLAG | SYS_EVENT_HUP) != 0 ||
            wait_is((unsigned int)job1, SYS_WAIT_EXITED,
            SYS_WAIT_EVENT_FLAG | SYS_EVENT_HUP) != 0 ||
            wait_is((unsigned int)job2, SYS_WAIT_EXITED,
            SYS_WAIT_EVENT_FLAG | SYS_EVENT_HUP) != 0)
                fail('4', 0204);
        if (dsys_procctl(SYS_PROCCTL_TTY_ATTACH, 0U) != 0 ||
            dsys_procctl(SYS_PROCCTL_GETTTY, 0U) !=
            (int)SYS_TTY_ATTACHED(0U) ||
            dsys_procctl(SYS_PROCCTL_TTY_GETFG, 0U) != 1)
                fail('5', 0205);
        (void)dsys_writechar(1, 'H');
        (void)dsys_exit(0);
        return 0;
}
