#include "dsys.h"
#include "../test_sixbit.h"

#define PRODUCER_MODE        0441U
#define CONSUMER_MODE        0442U

#define RUN_PATH_WORDS       3U
#define RUN_ARG_WORDS        2U
#define RUN_PATH_OFF         SYS_RUN_V2_FIXED_WORDS
#define RUN_ARG0_OFF         (RUN_PATH_OFF + RUN_PATH_WORDS)
#define RUN_ARG1_OFF         (RUN_ARG0_OFF + RUN_PATH_WORDS)
#define RUN_MAP_OFF          (RUN_ARG1_OFF + RUN_ARG_WORDS)
#define RUN_BLOCK_WORDS      (RUN_MAP_OFF + 5U)

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
    int job_fd, int ready_fd)
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
        mode_ch = mode == PRODUCER_MODE ? 'P' : 'C';
        block[RUN_ARG1_OFF] = 1UL;
        block[RUN_ARG1_OFF + 1U] =
            TEST_SIX6(mode_ch, ' ', ' ', ' ', ' ', ' ');
        n = 0U;
        block[RUN_MAP_OFF + n++] = SYS_RUN_FD_MAP(0U, 0U);
        block[RUN_MAP_OFF + n++] = SYS_RUN_FD_MAP(1U, 1U);
        block[RUN_MAP_OFF + n++] = SYS_RUN_FD_MAP(2U, 2U);
        block[RUN_MAP_OFF + n++] = SYS_RUN_FD_MAP(3U,
            (unsigned int)job_fd);
        block[RUN_MAP_OFF + n++] = SYS_RUN_FD_MAP(4U,
            (unsigned int)ready_fd);
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
        if (ch == 'P')
                return PRODUCER_MODE;
        if (ch == 'C')
                return CONSUMER_MODE;
        return 0U;
}

static int
send_group(unsigned int pgrp, unsigned int event)
{
        return dsys_procctl(SYS_PROCCTL_EVENT_PGRP,
            SYS_EVENT_ARG(pgrp, event));
}

static int
wait_group_pair(unsigned int pgrp, unsigned int pid1, unsigned int pid2,
    unsigned int kind, unsigned int value)
{
        kword_t status;
        int got;
        unsigned int seen;
        unsigned int i;

        seen = 0U;
        for (i = 0U; i < 2U; ++i) {
                status = 0UL;
                got = dsys_wait(SYS_WAIT_PGRP_FLAG | pgrp, &status, 0U);
                if (got == (int)pid1)
                        seen |= 1U;
                else if (got == (int)pid2)
                        seen |= 2U;
                else
                        return -1;
                if (SYS_WAIT_STATUS_KIND(status) != kind ||
                    SYS_WAIT_STATUS_VALUE(status) != value)
                        return -1;
        }
        return seen == 3U ? 0 : -1;
}

static void
fail(int ch, int status)
{
        (void)dsys_writechar(1, '!');
        (void)dsys_writechar(1, ch);
        (void)dsys_exit(status);
}

static int
pipe_send(int fd, kword_t word)
{
        return dsys_write_words(fd, &word, 1U) == 1 ? 0 : -1;
}

static int
pipe_recv(int fd, kword_t *word)
{
        return dsys_read_words(fd, word, 1U) == 1 ? 0 : -1;
}

int
main(int argc, kword_t **argv)
{
        kword_t ready;
        int pipe_r;
        int pipe_w;
        int ready_r;
        int ready_w;
        int producer;
        int consumer;
        unsigned int pgrp;
        unsigned int mode;

        mode = startup_mode(argc, argv);

        if (mode == PRODUCER_MODE) {
                if (pipe_send(3, 'P') != 0 || pipe_send(4, 'R') != 0)
                        (void)dsys_exit(0101);
                for (;;)
                        spin_word += 1UL;
        }
        if (mode == CONSUMER_MODE) {
                if (pipe_recv(3, &ready) != 0 || ready != 'P' ||
                    pipe_send(4, 'R') != 0)
                        (void)dsys_exit(0102);
                for (;;)
                        spin_word += 1UL;
        }
        if (mode != 1U || dsys_getpid() != 1)
                fail('0', 0200);
        if (dsys_writechar(1, '<') != 0 ||
            dsys_procctl(SYS_PROCCTL_TTY_ATTACH, 0U) != 0 ||
            new_pipe(&pipe_r, &pipe_w) != 0 ||
            new_pipe(&ready_r, &ready_w) != 0)
                fail('1', 0201);
        producer = spawn(PRODUCER_MODE, SYS_RUN_PGRP_NEW, 0U,
            pipe_w, ready_w);
        if (producer <= 1)
                fail('2', 0202);
        pgrp = (unsigned int)producer;
        consumer = spawn(CONSUMER_MODE, SYS_RUN_PGRP_JOIN, pgrp,
            pipe_r, ready_w);
        if (consumer <= producer || dsys_close(pipe_r) != 0 ||
            dsys_close(pipe_w) != 0 || dsys_close(ready_w) != 0 ||
            pipe_recv(ready_r, &ready) != 0 || ready != 'R' ||
            pipe_recv(ready_r, &ready) != 0 || ready != 'R' ||
            dsys_close(ready_r) != 0)
                fail('3', 0203);

        if (dsys_procctl(SYS_PROCCTL_TTY_SETFG, pgrp) != (int)pgrp ||
            send_group(pgrp, SYS_EVENT_TSTP) != 0 ||
            wait_group_pair(pgrp, (unsigned int)producer,
            (unsigned int)consumer, SYS_WAIT_STOPPED, SYS_EVENT_TSTP) != 0)
                fail('4', 0204);

        if (dsys_procctl(SYS_PROCCTL_TTY_SETFG, 1U) != 1 ||
            send_group(pgrp, SYS_EVENT_CONT) != 0 ||
            wait_group_pair(pgrp, (unsigned int)producer,
            (unsigned int)consumer, SYS_WAIT_CONTINUED, SYS_EVENT_CONT) != 0 ||
            dsys_procctl(SYS_PROCCTL_TTY_GETFG, 0U) != 1)
                fail('5', 0205);

        if (send_group(pgrp, SYS_EVENT_TSTP) != 0 ||
            wait_group_pair(pgrp, (unsigned int)producer,
            (unsigned int)consumer, SYS_WAIT_STOPPED, SYS_EVENT_TSTP) != 0 ||
            dsys_procctl(SYS_PROCCTL_TTY_SETFG, pgrp) != (int)pgrp ||
            send_group(pgrp, SYS_EVENT_CONT) != 0 ||
            wait_group_pair(pgrp, (unsigned int)producer,
            (unsigned int)consumer, SYS_WAIT_CONTINUED, SYS_EVENT_CONT) != 0 ||
            dsys_procctl(SYS_PROCCTL_TTY_GETFG, 0U) != (int)pgrp)
                fail('6', 0206);

        if (send_group(pgrp, SYS_EVENT_TERM) != 0 ||
            wait_group_pair(pgrp, (unsigned int)producer,
            (unsigned int)consumer, SYS_WAIT_EXITED,
            SYS_WAIT_EVENT_FLAG | SYS_EVENT_TERM) != 0 ||
            dsys_procctl(SYS_PROCCTL_TTY_SETFG, 1U) != 1)
                fail('7', 0207);

        (void)dsys_writechar(1, 'H');
        (void)dsys_exit(0);
        return 0;
}
