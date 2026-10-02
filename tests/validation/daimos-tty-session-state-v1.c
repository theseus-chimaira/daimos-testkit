#include "dsys.h"
#include "../test_sixbit.h"

#define CHILD_MODE           0441U
#define CHILD_STATUS         062U

#define RUN_PATH_WORDS       3U
#define RUN_ARG_WORDS        2U
#define RUN_PATH_OFF         SYS_RUN_V2_FIXED_WORDS
#define RUN_ARG0_OFF         (RUN_PATH_OFF + RUN_PATH_WORDS)
#define RUN_ARG1_OFF         (RUN_ARG0_OFF + RUN_PATH_WORDS)
#define RUN_MAP_OFF          (RUN_ARG1_OFF + RUN_ARG_WORDS)
#define RUN_BLOCK_WORDS      (RUN_MAP_OFF + 5U)

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
spawn_child(int command_fd, int report_fd)
{
        kword_t block[RUN_BLOCK_WORDS];
        struct sys_run_v2 *run;
        unsigned int i;

        for (i = 0U; i < RUN_BLOCK_WORDS; ++i)
                block[i] = 0UL;
        run = (struct sys_run_v2 *)block;
        run->flags = SYS_RUN_PGRP_INHERIT;
        run->pgrp = 0UL;
        run->fdmap_count = 5UL;
        run->argc = 2UL;
        run->envc = 0UL;
        for (i = 0U; i < RUN_PATH_WORDS; ++i) {
                block[RUN_PATH_OFF + i] = init_path[i];
                block[RUN_ARG0_OFF + i] = init_path[i];
        }
        block[RUN_ARG1_OFF] = 1UL;
        block[RUN_ARG1_OFF + 1U] =
            TEST_SIX6('C', ' ', ' ', ' ', ' ', ' ');
        block[RUN_MAP_OFF] = SYS_RUN_FD_MAP(0U, 0U);
        block[RUN_MAP_OFF + 1U] = SYS_RUN_FD_MAP(1U, 1U);
        block[RUN_MAP_OFF + 2U] = SYS_RUN_FD_MAP(2U, 2U);
        block[RUN_MAP_OFF + 3U] = SYS_RUN_FD_MAP(3U,
            (unsigned int)command_fd);
        block[RUN_MAP_OFF + 4U] = SYS_RUN_FD_MAP(4U,
            (unsigned int)report_fd);
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
        return ch == 'C' ? CHILD_MODE : 0U;
}

static int
wait_exit(unsigned int pid, unsigned int status_value)
{
        kword_t status;
        int got;

        status = 0UL;
        got = dsys_wait(pid, &status, 0U);
        return got == (int)pid &&
            SYS_WAIT_STATUS_KIND(status) == SYS_WAIT_EXITED &&
            SYS_WAIT_STATUS_VALUE(status) == status_value ? 0 : -1;
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

static void
fail(int ch, int status)
{
        (void)dsys_writechar(1, '!');
        (void)dsys_writechar(1, ch);
        (void)dsys_exit(status);
}

static void
child_main(void)
{
        kword_t command;

        if (dsys_procctl(SYS_PROCCTL_GETTTY, 0U) !=
            (int)SYS_TTY_ATTACHED(0U) || pipe_send(4, 'A') != 0)
                (void)dsys_exit(0101);
        if (pipe_recv(3, &command) != 0 || command != 'D' ||
            dsys_procctl(SYS_PROCCTL_GETTTY, 0U) != SYS_TTY_DETACHED ||
            pipe_send(4, 'D') != 0)
                (void)dsys_exit(0102);
        if (pipe_recv(3, &command) != 0 || command != 'A' ||
            dsys_procctl(SYS_PROCCTL_GETTTY, 0U) !=
            (int)SYS_TTY_ATTACHED(0U) || pipe_send(4, 'A') != 0)
                (void)dsys_exit(0103);
        if (pipe_recv(3, &command) != 0 || command != 'X')
                (void)dsys_exit(0104);
        (void)dsys_exit(CHILD_STATUS);
}

int
main(int argc, kword_t **argv)
{
        kword_t report;
        int command_r;
        int command_w;
        int report_r;
        int report_w;
        int child;
        unsigned int mode;

        mode = startup_mode(argc, argv);

        if (mode == CHILD_MODE) {
                child_main();
                return 0;
        }
        if (mode != 1U || dsys_getpid() != 1)
                fail('0', 0200);
        if (dsys_writechar(1, '<') != 0 ||
            dsys_procctl(SYS_PROCCTL_TTY_ATTACH, 0U) != 0 ||
            new_pipe(&command_r, &command_w) != 0 ||
            new_pipe(&report_r, &report_w) != 0)
                fail('1', 0201);
        child = spawn_child(command_r, report_w);
        if (child <= 1 || dsys_close(command_r) != 0 ||
            dsys_close(report_w) != 0 || pipe_recv(report_r, &report) != 0 ||
            report != 'A')
                fail('2', 0202);

        if (dsys_procctl(SYS_PROCCTL_TTY_DETACH, 0U) != 0 ||
            dsys_procctl(SYS_PROCCTL_GETTTY, 0U) != SYS_TTY_DETACHED ||
            pipe_send(command_w, 'D') != 0 ||
            pipe_recv(report_r, &report) != 0 || report != 'D')
                fail('3', 0203);

        if (dsys_procctl(SYS_PROCCTL_TTY_ATTACH, 0U) != 0 ||
            dsys_procctl(SYS_PROCCTL_GETTTY, 0U) !=
            (int)SYS_TTY_ATTACHED(0U) ||
            pipe_send(command_w, 'A') != 0 ||
            pipe_recv(report_r, &report) != 0 || report != 'A')
                fail('4', 0204);

        if (pipe_send(command_w, 'X') != 0 ||
            wait_exit((unsigned int)child, CHILD_STATUS) != 0 ||
            dsys_close(command_w) != 0 || dsys_close(report_r) != 0)
                fail('5', 0205);
        /* Keep the controlling TTY through the success marker.  A process
         * that has just detached it cannot report success through fd 1;
         * detach/reattach propagation was already verified above. */
        (void)dsys_writechar(1, 'H');
        (void)dsys_exit(0);
        return 0;
}
