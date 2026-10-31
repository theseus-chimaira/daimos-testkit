#include "dsys.h"
#include "../test_sixbit.h"

#define LEADER_MODE          0431U
#define JOB_MODE             0432U
#define BYSTANDER_MODE       0433U
#define LEADER_STATUS        061U

#define RUN_PATH_WORDS       3U
#define RUN_ARG_WORDS        2U
#define RUN_PATH_OFF         SYS_RUN_V2_FIXED_WORDS
#define RUN_ARG0_OFF         (RUN_PATH_OFF + RUN_PATH_WORDS)
#define RUN_ARG1_OFF         (RUN_ARG0_OFF + RUN_PATH_WORDS)
#define RUN_MAP_OFF          (RUN_ARG1_OFF + RUN_ARG_WORDS)
#define RUN_BLOCK_WORDS      (RUN_MAP_OFF + 4U)

static volatile kword_t spin_word;

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
        mode_ch = mode == LEADER_MODE ? 'L' :
            mode == BYSTANDER_MODE ? 'B' : 'J';
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
        if (ch == 'B')
                return BYSTANDER_MODE;
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
        (void)dsys_exit(LEADER_STATUS);
}

int
main(int argc, kword_t **argv)
{
        int bystander;
        kword_t report;
        int report_r;
        int report_w;
        int leader;
        int job1;
        int job2;
        int td_self;
        int td_invalid;
        unsigned int mode;

        mode = startup_mode(argc, argv);

        /* The actual UUO route must agree with the native diagnostic.
         * An ordinary running process has no fatal cleanup owner. */
        td_self = dsys_procctl(SYS_PROCCTL_GETTEARDOWN,
            (unsigned int)dsys_getpid());
        td_invalid = dsys_procctl(SYS_PROCCTL_GETTEARDOWN, 0377U);
        (void)dsys_writechar(1, td_self == 0 ? 'N' : 'X');
        (void)dsys_writechar(1, td_invalid == -1 ? 'V' : 'Y');
        if (td_self != SYS_TEARDOWN_NONE || td_invalid != -1)
                (void)dsys_exit(0266);
        if (dsys_procctl(SYS_PROCCTL_GETTEARDOWN,
            SYS_TEARDOWN_DETAIL_ARG(dsys_getpid())) != SYS_TEARDOWN_NONE ||
            dsys_procctl(SYS_PROCCTL_GETTEARDOWN,
            SYS_TEARDOWN_DETAIL_ARG(0377U)) != -1)
                (void)dsys_exit(0267);

    if (mode == BYSTANDER_MODE) {
                (void)dsys_writechar(1, 'B');
                for (;;)
                        spin_word += 1UL;
    }
    if (mode == JOB_MODE) {
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
        /* Independent permanently runnable user, not in leader's pgrp.
         * It remains runnable until both HUP zombies have been reaped. */
        bystander = spawn(BYSTANDER_MODE, SYS_RUN_PGRP_NEW, 0U, -1);
        if (bystander <= 1 || bystander == job1 || bystander == job2)
                fail('6', 0206);
        if (wait_is((unsigned int)leader, SYS_WAIT_EXITED,
            LEADER_STATUS) != 0 ||
            wait_is((unsigned int)job1, SYS_WAIT_EXITED,
            SYS_WAIT_EVENT_FLAG | SYS_EVENT_HUP) != 0 ||
            wait_is((unsigned int)job2, SYS_WAIT_EXITED,
            SYS_WAIT_EVENT_FLAG | SYS_EVENT_HUP) != 0)
                fail('4', 0204);
        if (dsys_procctl(SYS_PROCCTL_EVENT_PID,
            SYS_EVENT_ARG((unsigned int)bystander, SYS_EVENT_TERM)) != 0 ||
            wait_is((unsigned int)bystander, SYS_WAIT_EXITED,
            SYS_WAIT_EVENT_FLAG | SYS_EVENT_TERM) != 0)
                fail('7', 0207);
        if (dsys_procctl(SYS_PROCCTL_TTY_ATTACH, 0U) != 0 ||
            dsys_procctl(SYS_PROCCTL_GETTTY, 0U) !=
            (int)SYS_TTY_ATTACHED(0U) ||
            dsys_procctl(SYS_PROCCTL_TTY_GETFG, 0U) != 1)
                fail('5', 0205);
        (void)dsys_writechar(1, 'H');
        (void)dsys_exit(0);
        return 0;
}
