#include "dsys.h"
#include "proc.h"

#define WRITER_MODE          0131U
#define JOB_MODE             0132U
#define PRESSURE_MODE        0133U
#define RUN_PATH_WORDS       3U
#define RUN_ARG_WORDS        2U
#define RUN_PATH_OFF         SYS_RUN_V2_FIXED_WORDS
#define RUN_ARG0_OFF         (RUN_PATH_OFF + RUN_PATH_WORDS)
#define RUN_ARG1_OFF         (RUN_ARG0_OFF + RUN_PATH_WORDS)
#define RUN_MAP_OFF          (RUN_ARG1_OFF + RUN_ARG_WORDS)
#define RUN_BLOCK_WORDS      (RUN_MAP_OFF + 4U)
#define WAIT_SPINS           020000U
#define PIPE_WORDS           8U
#define WRITER_STATUS        050U
#define JOB_STATUS           051U
#define PRESSURE_STATUS      052U
#define TEST_SIXCHAR(ch) \
        ((unsigned long)(((unsigned int)(ch) - 040U) & 077U))
#define TEST_SIX6(a,b,c,d,e,f) \
        ((TEST_SIXCHAR(a) << 30) | (TEST_SIXCHAR(b) << 24) | \
        (TEST_SIXCHAR(c) << 18) | (TEST_SIXCHAR(d) << 12) | \
        (TEST_SIXCHAR(e) << 6) | TEST_SIXCHAR(f))

/* Every invocation of /SYSTEM/INIT carries this array.  Parent, target and
 * one sleeping pressure child fit in 32K; a second pressure child crosses the
 * current lowmem resident threshold and forces the blocked/stopped target out. */
static volatile kword_t pressure_area[010000];
static volatile kword_t burn_word;

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

static void
touch_image(unsigned int mode)
{
        pressure_area[0] = (kword_t)mode;
        pressure_area[07777] = (kword_t)mode ^ 0123456701234UL;
}

static void
burn(void)
{
        unsigned int i;

        for (i = 0U; i < 0400U; ++i)
                burn_word = (burn_word + (kword_t)i + 1UL) & 0777777777777UL;
}

static int
new_pipe(int *read_fd, int *write_fd)
{
        kword_t pair;

        pair = dsys_pipe();
        if (pair == ~0UL)
                return -1;
        *read_fd = (int)((pair >> 18U) & 0777777UL);
        *write_fd = (int)(pair & 0777777UL);
        return *read_fd >= 0 && *read_fd < 16 && *write_fd >= 0 &&
            *write_fd < 16 && *read_fd != *write_fd ? 0 : -1;
}

static int
spawn_child(unsigned int mode, unsigned int pgrp_mode, unsigned int pgrp,
    int input_fd, int data_fd)
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
        mode_ch = mode == WRITER_MODE ? 'W' :
            (mode == JOB_MODE ? 'J' : 'P');
        block[RUN_ARG1_OFF] = 1UL;
        block[RUN_ARG1_OFF + 1U] =
            TEST_SIX6(mode_ch, ' ', ' ', ' ', ' ', ' ');
        n = 0U;
        block[RUN_MAP_OFF + n++] = SYS_RUN_FD_MAP(0U,
            (unsigned int)input_fd);
        block[RUN_MAP_OFF + n++] = SYS_RUN_FD_MAP(1U, 1U);
        block[RUN_MAP_OFF + n++] = SYS_RUN_FD_MAP(2U, 2U);
        if (data_fd >= 0)
                block[RUN_MAP_OFF + n++] = SYS_RUN_FD_MAP(3U,
                    (unsigned int)data_fd);
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
        if (ch == 'W') return WRITER_MODE;
        if (ch == 'J') return JOB_MODE;
        if (ch == 'P') return PRESSURE_MODE;
        return 0U;
}

static int
wait_state(unsigned int pid, unsigned int state)
{
        struct sys_procinfo info;
        unsigned int i;

        for (i = 0U; i < WAIT_SPINS; ++i) {
                if (dsys_procinfo(pid, &info) == 0 && info.state == state)
                        return 0;
                burn();
        }
        return -1;
}

static int
wait_report(unsigned int pid, unsigned int kind, unsigned int value)
{
        kword_t status;
        int got;

        status = 0UL;
        got = dsys_wait(pid, &status, 0U);
        if (got != (int)pid || SYS_WAIT_STATUS_KIND(status) != kind ||
            SYS_WAIT_STATUS_VALUE(status) != value)
                return -1;
        return 0;
}

/* The target is deliberately aged before the later pressure sleepers exist,
 * making it the preferred swap victim.  Reclaim may evict more than one user
 * image before this query, so require at least one complete target-sized
 * extent to be absent rather than assuming both pressure children stay
 * resident. */
static int
target_is_swapped(unsigned int target, unsigned int pressure_a,
    unsigned int pressure_b)
{
        struct sys_meminfo mem;
        struct sys_procinfo parent_info;
        struct sys_procinfo target_info;
        struct sys_procinfo pressure_a_info;
        struct sys_procinfo pressure_b_info;
        kword_t all_resident;

        if (dsys_meminfo(&mem) != 0 ||
            dsys_procinfo(1U, &parent_info) != 0 ||
            dsys_procinfo(target, &target_info) != 0 ||
            dsys_procinfo(pressure_a, &pressure_a_info) != 0 ||
            dsys_procinfo(pressure_b, &pressure_b_info) != 0)
                return 0;
        all_resident = parent_info.words + target_info.words +
            pressure_a_info.words + pressure_b_info.words +
            4UL * PROC_UAREA_WORDS;
        return target_info.words != 0UL &&
            all_resident >= mem.process_words + target_info.words;
}

static int
send_group(unsigned int pgrp, unsigned int event)
{
        return dsys_procctl(SYS_PROCCTL_EVENT_PGRP,
            SYS_EVENT_ARG(pgrp, event));
}

static int
drain_pipe(int fd, int fill, int tail)
{
        unsigned int i;
        kword_t word;

        for (i = 1U; i < PIPE_WORDS; ++i) {
                if (dsys_read_words(fd, &word, 1U) != 1 || word != (kword_t)fill)
                        return -1;
        }
        if (dsys_read_words(fd, &word, 1U) != 1 || word != (kword_t)tail ||
            dsys_read_words(fd, &word, 1U) != 0)
                return -1;
        return 0;
}

static int
finish_pressures(int gate_w, int pressure_a, int pressure_b)
{
        if (dsys_close(gate_w) != 0)
                return -1;
        if (wait_report((unsigned int)pressure_a, SYS_WAIT_EXITED,
            PRESSURE_STATUS) != 0)
                return -1;
        return wait_report((unsigned int)pressure_b, SYS_WAIT_EXITED,
            PRESSURE_STATUS);
}

static int
run_writer_case(void)
{
        int pipe_r;
        int pipe_w;
        int gate_r;
        int gate_w;
        int writer;
        int pressure_a;
        int pressure_b;
        kword_t word;

        if (new_pipe(&pipe_r, &pipe_w) != 0 ||
            new_pipe(&gate_r, &gate_w) != 0) {
                (void)mark('a');
                return -1;
        }
        writer = spawn_child(WRITER_MODE, SYS_RUN_PGRP_INHERIT, 0U, 0,
            pipe_w);
        if (writer <= 1 || dsys_close(pipe_w) != 0 ||
            wait_state((unsigned int)writer, PROC_SLEEP) != 0) {
                (void)mark('b');
                return -1;
        }
        if (dsys_sleep(0200U) != 0) {
                (void)mark('x');
                return -1;
        }

        pressure_a = spawn_child(PRESSURE_MODE, SYS_RUN_PGRP_INHERIT, 0U,
            gate_r, -1);
        if (pressure_a <= writer ||
            wait_state((unsigned int)pressure_a, PROC_SLEEP) != 0) {
                (void)mark('p');
                return -1;
        }
        pressure_b = spawn_child(PRESSURE_MODE, SYS_RUN_PGRP_INHERIT, 0U,
            gate_r, -1);
        if (pressure_b <= 1 || pressure_b == pressure_a || pressure_b == writer) {
                (void)mark('q');
                return -1;
        }
        if (dsys_close(gate_r) != 0) {
                (void)mark('r');
                return -1;
        }
        if (wait_state((unsigned int)pressure_b, PROC_SLEEP) != 0) {
                (void)mark('t');
                return -1;
        }
        if (!target_is_swapped((unsigned int)writer,
            (unsigned int)pressure_a, (unsigned int)pressure_b)) {
                (void)mark('s');
                return -1;
        }

        /* One read creates exactly one free pipe slot.  Waking the nonresident
         * writer must invoke slot-0 swap-in before the pending 129th write can
         * complete. */
        if (dsys_read_words(pipe_r, &word, 1U) != 1 || word != 'A' ||
            wait_report((unsigned int)writer, SYS_WAIT_EXITED,
            WRITER_STATUS) != 0 || drain_pipe(pipe_r, 'A', 'Z') != 0 ||
            dsys_close(pipe_r) != 0) {
                (void)mark('d');
                return -1;
        }
        if (finish_pressures(gate_w, pressure_a, pressure_b) != 0) {
                (void)mark('e');
                return -1;
        }
        return 0;
}

static int
run_stopped_job_case(void)
{
        int pipe_r;
        int pipe_w;
        int gate_r;
        int gate_w;
        int job;
        int pressure_a;
        int pressure_b;
        unsigned int pgrp;
        kword_t word;

        if (new_pipe(&pipe_r, &pipe_w) != 0 ||
            new_pipe(&gate_r, &gate_w) != 0)
                return -1;
        job = spawn_child(JOB_MODE, SYS_RUN_PGRP_NEW, 0U, 0, pipe_w);
        if (job <= 1 || dsys_close(pipe_w) != 0 ||
            wait_state((unsigned int)job, PROC_SLEEP) != 0)
                return -1;
        pgrp = (unsigned int)job;
        if (send_group(pgrp, SYS_EVENT_TSTP) != 0 ||
            wait_report((unsigned int)job, SYS_WAIT_STOPPED,
            SYS_EVENT_TSTP) != 0 || wait_state((unsigned int)job,
            PROC_STOP) != 0)
                return -1;
        if (dsys_sleep(0200U) != 0)
                return -1;

        pressure_a = spawn_child(PRESSURE_MODE, SYS_RUN_PGRP_INHERIT, 0U,
            gate_r, -1);
        if (pressure_a <= job ||
            wait_state((unsigned int)pressure_a, PROC_SLEEP) != 0)
                return -1;
        pressure_b = spawn_child(PRESSURE_MODE, SYS_RUN_PGRP_INHERIT, 0U,
            gate_r, -1);
        if (pressure_b <= 1 || pressure_b == pressure_a || pressure_b == job ||
            dsys_close(gate_r) != 0 ||
            wait_state((unsigned int)pressure_b, PROC_SLEEP) != 0 ||
            wait_state((unsigned int)job, PROC_STOP) != 0 ||
            !target_is_swapped((unsigned int)job,
            (unsigned int)pressure_a, (unsigned int)pressure_b))
                return -1;

        /* Foreground transfer is deliberately performed while the stopped job
         * is nonresident.  CONT removes the job-control stop; the pending full
         * pipe write remains asleep until the read below makes room, at which
         * point normal scheduling must restore the job and resume it. */
        if (dsys_procctl(SYS_PROCCTL_TTY_SETFG, pgrp) != (int)pgrp ||
            send_group(pgrp, SYS_EVENT_CONT) != 0 ||
            wait_report((unsigned int)job, SYS_WAIT_CONTINUED,
            SYS_EVENT_CONT) != 0 || wait_state((unsigned int)job,
            PROC_SLEEP) != 0)
                return -1;
        if (dsys_read_words(pipe_r, &word, 1U) != 1 || word != 'B' ||
            wait_report((unsigned int)job, SYS_WAIT_EXITED,
            JOB_STATUS) != 0 || drain_pipe(pipe_r, 'B', 'K') != 0 ||
            dsys_close(pipe_r) != 0 ||
            dsys_procctl(SYS_PROCCTL_TTY_SETFG, 1U) != 1)
                return -1;
        if (finish_pressures(gate_w, pressure_a, pressure_b) != 0)
                return -1;
        return 0;
}

int
main(int argc, kword_t **argv)
{
        unsigned int i;
        kword_t word;
        unsigned int mode;

        mode = startup_mode(argc, argv);

        touch_image(mode);
        if (mode == WRITER_MODE) {
                word = 'A';
                for (i = 0U; i < PIPE_WORDS; ++i) {
                        if (dsys_write_words(3, &word, 1U) != 1)
                                (void)dsys_exit(041);
                }
                word = 'Z';
                if (mark('w') != 0 || dsys_write_words(3, &word, 1U) != 1)
                        (void)dsys_exit(042);
                (void)dsys_exit(WRITER_STATUS);
                return WRITER_STATUS;
        }
        if (mode == JOB_MODE) {
                word = 'B';
                for (i = 0U; i < PIPE_WORDS; ++i) {
                        if (dsys_write_words(3, &word, 1U) != 1)
                                (void)dsys_exit(043);
                }
                word = 'K';
                if (mark('j') != 0 || dsys_write_words(3, &word, 1U) != 1)
                        (void)dsys_exit(044);
                if (mark('J') != 0)
                        (void)dsys_exit(045);
                (void)dsys_exit(JOB_STATUS);
                return JOB_STATUS;
        }
        if (mode == PRESSURE_MODE) {
                if (dsys_read_words(0, &word, 1U) != 0)
                        (void)dsys_exit(046);
                (void)dsys_exit(PRESSURE_STATUS);
                return PRESSURE_STATUS;
        }
        if (mode != 1U || dsys_getpid() != 1)
                fail('0', 010);
        /* INIT requests both AUTO services together.  LOGSTORE may be absent
         * in this reduced image, but that must not suppress independent SWAP
         * activation; the pressure cases below prove SWAP actually came up. */
        (void)dsys_storagectl(SYS_STORAGECTL_SWAP | SYS_STORAGECTL_LOGSTORE);

        if (mark('<') != 0 || run_writer_case() != 0)
                fail('W', 011);
        if (mark('1') != 0 ||
            dsys_procctl(SYS_PROCCTL_TTY_ATTACH, 0U) != 0 ||
            dsys_procctl(SYS_PROCCTL_TTY_GETFG, 0U) != 1 ||
            run_stopped_job_case() != 0)
                fail('J', 012);
        if (mark('Q') != 0)
                fail('Q', 013);
        (void)dsys_exit(0);
        return 0;
}
