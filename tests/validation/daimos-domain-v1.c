#include "dsys.h"
#include "../test_sixbit.h"

#define CHILD_MODE  0301U
#define MEMBER_MODE 0302U
#define PROC_STATE_ZOMB 4U

#define RUN_PATH_WORDS 3U
#define RUN_ARG_WORDS 2U
#define RUN_PATH_OFF SYS_RUN_V2_FIXED_WORDS
#define RUN_ARG0_OFF (RUN_PATH_OFF + RUN_PATH_WORDS)
#define RUN_ARG1_OFF (RUN_ARG0_OFF + RUN_PATH_WORDS)
#define RUN_MAP_OFF (RUN_ARG1_OFF + RUN_ARG_WORDS)
#define RUN_BLOCK_WORDS (RUN_MAP_OFF + 3U)
#define RUN_HOLD_BLOCK_WORDS (RUN_MAP_OFF + 4U)

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
spawn(unsigned int mode, unsigned int pgrp_mode)
{
        kword_t block[RUN_BLOCK_WORDS];
        struct sys_run_v2 *run;
        unsigned int i;

        for (i = 0U; i < RUN_BLOCK_WORDS; ++i)
                block[i] = 0UL;
        run = (struct sys_run_v2 *)block;
        run->flags = (kword_t)pgrp_mode;
        run->pgrp = 0UL;
        run->fdmap_count = 3UL;
        run->argc = 2UL;
        run->envc = 0UL;
        for (i = 0U; i < RUN_PATH_WORDS; ++i) {
                block[RUN_PATH_OFF + i] = init_path[i];
                block[RUN_ARG0_OFF + i] = init_path[i];
        }
        block[RUN_ARG1_OFF] = 1UL;
        block[RUN_ARG1_OFF + 1U] =
            TEST_SIX6(mode == CHILD_MODE ? 'C' : 'M',
            ' ', ' ', ' ', ' ', ' ');
        block[RUN_MAP_OFF] = SYS_RUN_FD_MAP(0U, 0U);
        block[RUN_MAP_OFF + 1U] = SYS_RUN_FD_MAP(1U, 1U);
        block[RUN_MAP_OFF + 2U] = SYS_RUN_FD_MAP(2U, 2U);
        run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
            RUN_BLOCK_WORDS);
        return dsys_run(run);
}

static int
spawn_held(unsigned int mode, unsigned int pgrp_mode, int hold_fd)
{
        kword_t block[RUN_HOLD_BLOCK_WORDS];
        struct sys_run_v2 *run;
        unsigned int i;

        for (i = 0U; i < RUN_HOLD_BLOCK_WORDS; ++i)
                block[i] = 0UL;
        run = (struct sys_run_v2 *)block;
        run->flags = (kword_t)pgrp_mode;
        run->pgrp = 0UL;
        run->fdmap_count = 4UL;
        run->argc = 2UL;
        run->envc = 0UL;
        for (i = 0U; i < RUN_PATH_WORDS; ++i) {
                block[RUN_PATH_OFF + i] = init_path[i];
                block[RUN_ARG0_OFF + i] = init_path[i];
        }
        block[RUN_ARG1_OFF] = 1UL;
        block[RUN_ARG1_OFF + 1U] =
            TEST_SIX6(mode == CHILD_MODE ? 'C' : 'M',
            ' ', ' ', ' ', ' ', ' ');
        block[RUN_MAP_OFF] = SYS_RUN_FD_MAP(0U, 0U);
        block[RUN_MAP_OFF + 1U] = SYS_RUN_FD_MAP(1U, 1U);
        block[RUN_MAP_OFF + 2U] = SYS_RUN_FD_MAP(2U, 2U);
        block[RUN_MAP_OFF + 3U] = SYS_RUN_FD_MAP(3U, (unsigned int)hold_fd);
        run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
            RUN_HOLD_BLOCK_WORDS);
        return dsys_run(run);
}

static unsigned int
startup_mode(int argc, kword_t **argv)
{
        if (argc == 1)
                return 1U;
        if (argc != 2 || argv == 0 || argv[1] == 0 || argv[1][0] != 1UL)
                return 0U;
        if (argv[1][1] == TEST_SIX6('C', ' ', ' ', ' ', ' ', ' '))
                return CHILD_MODE;
        if (argv[1][1] == TEST_SIX6('M', ' ', ' ', ' ', ' ', ' '))
                return MEMBER_MODE;
        return 0U;
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
        if (*read_fd < 0 || *read_fd >= 16 || *write_fd < 0 ||
            *write_fd >= 16 || *read_fd == *write_fd)
                return -1;
        return 0;
}

static int
wait_zombie_by_eof(unsigned int pid, int read_fd, int write_fd)
{
        struct sys_procinfo info;
        kword_t word;

        if (dsys_close(write_fd) != 0 ||
            dsys_read_words(read_fd, &word, 1U) != 0 ||
            dsys_close(read_fd) != 0)
                return -1;
        if (dsys_procinfo(pid, &info) != 0 || info.state != PROC_STATE_ZOMB)
                return -1;
        return 0;
}

static int
read_decimal_leaf(kword_t *path, kword_t *valuep)
{
        kword_t record[2];
        kword_t value;
        unsigned int chars;
        unsigned int i;
        unsigned int shift;
        int fd;
        int ch;
        int n;

        if (valuep == 0)
                return -1;
        fd = dsys_open(path, SYS_O_RDONLY);
        if (fd < 3)
                return -1;
        n = dsys_read_words(fd, record, 2U);
        if (dsys_close(fd) != 0 || n != 2 ||
            ((record[0] >> 30U) & 077UL) != 1UL)
                return -1;
        chars = (unsigned int)(record[0] & 077777777UL);
        if (chars == 0U || chars > 6U)
                return -1;
        value = 0UL;
        for (i = 0U; i < chars; ++i) {
                shift = 30U - i * 6U;
                ch = (int)(((record[1] >> shift) & 077UL) + 040UL);
                if (ch < '0' || ch > '9') {
                        return -1;
                }
                value = value * 10UL + (kword_t)(ch - '0');
        }
        *valuep = value;
        return 0;
}

static int
read_domain_status(kword_t *status)
{
        static kword_t processes[] = {
                28UL,
                TEST_SIX6('/', 'M', 'O', 'N', 'I', 'T'),
                TEST_SIX6('O', 'R', '/', 'D', 'O', 'M'),
                TEST_SIX6('A', 'I', 'N', 'S', '/', '2'),
                TEST_SIX6('/', 'P', 'R', 'O', 'C', 'E'),
                TEST_SIX6('S', 'S', 'E', 'S', ' ', ' ')
        };
        static kword_t words[] = {
                24UL,
                TEST_SIX6('/', 'M', 'O', 'N', 'I', 'T'),
                TEST_SIX6('O', 'R', '/', 'D', 'O', 'M'),
                TEST_SIX6('A', 'I', 'N', 'S', '/', '2'),
                TEST_SIX6('/', 'W', 'O', 'R', 'D', 'S')
        };
        static kword_t swapped[] = {
                26UL,
                TEST_SIX6('/', 'M', 'O', 'N', 'I', 'T'),
                TEST_SIX6('O', 'R', '/', 'D', 'O', 'M'),
                TEST_SIX6('A', 'I', 'N', 'S', '/', '2'),
                TEST_SIX6('/', 'S', 'W', 'A', 'P', 'P'),
                TEST_SIX6('E', 'D', ' ', ' ', ' ', ' ')
        };
        static kword_t swapwords[] = {
                28UL,
                TEST_SIX6('/', 'M', 'O', 'N', 'I', 'T'),
                TEST_SIX6('O', 'R', '/', 'D', 'O', 'M'),
                TEST_SIX6('A', 'I', 'N', 'S', '/', '2'),
                TEST_SIX6('/', 'S', 'W', 'A', 'P', 'W'),
                TEST_SIX6('O', 'R', 'D', 'S', ' ', ' ')
        };
        static kword_t stopped[] = {
                26UL,
                TEST_SIX6('/', 'M', 'O', 'N', 'I', 'T'),
                TEST_SIX6('O', 'R', '/', 'D', 'O', 'M'),
                TEST_SIX6('A', 'I', 'N', 'S', '/', '2'),
                TEST_SIX6('/', 'S', 'T', 'O', 'P', 'P'),
                TEST_SIX6('E', 'D', ' ', ' ', ' ', ' ')
        };

        if (status == 0)
                return -1;
        status[0] = 2UL;
        if (read_decimal_leaf(processes, &status[1]) != 0 ||
            read_decimal_leaf(words, &status[2]) != 0 ||
            read_decimal_leaf(swapped, &status[3]) != 0 ||
            read_decimal_leaf(swapwords, &status[4]) != 0 ||
            read_decimal_leaf(stopped, &status[5]) != 0)
                return -1;
        return 0;
}

static int
domain_dir_has_two(void)
{
        static kword_t root[] = {
                16UL,
                TEST_SIX6('/', 'M', 'O', 'N', 'I', 'T'),
                TEST_SIX6('O', 'R', '/', 'D', 'O', 'M'),
                TEST_SIX6('A', 'I', 'N', 'S', ' ', ' ')
        };
        struct vfs_dirent ent;
        int fd;
        int rc;

        fd = dsys_open(root, SYS_O_RDONLY);
        if (fd < 3)
                return -1;
        for (;;) {
                rc = dsys_dirread(fd, &ent);
                if (rc <= 0)
                        break;
                if (ent.name.chars == 1U &&
                    ent.name.words[0] == TEST_SIX6('2', ' ', ' ', ' ', ' ', ' ')) {
                        (void)dsys_close(fd);
                        return 0;
                }
        }
        (void)dsys_close(fd);
        return -1;
}

static int
domain_cwd_two(void)
{
        static kword_t monitor[] = {
                8UL,
                TEST_SIX6('/', 'M', 'O', 'N', 'I', 'T'),
                TEST_SIX6('O', 'R', ' ', ' ', ' ', ' ')
        };
        static kword_t domains[] = {
                16UL,
                TEST_SIX6('/', 'M', 'O', 'N', 'I', 'T'),
                TEST_SIX6('O', 'R', '/', 'D', 'O', 'M'),
                TEST_SIX6('A', 'I', 'N', 'S', ' ', ' ')
        };
        static kword_t path[] = {
                18UL,
                TEST_SIX6('/', 'M', 'O', 'N', 'I', 'T'),
                TEST_SIX6('O', 'R', '/', 'D', 'O', 'M'),
                TEST_SIX6('A', 'I', 'N', 'S', '/', '2')
        };
        kword_t cwd[8];
        unsigned int i;
        unsigned int word;
        unsigned int shift;

        if (dsys_chdir(monitor) != 0 || dsys_getcwd(cwd, 8U) != 0) {
                (void)mark('M');
                return -1;
        }
        if (dsys_chdir(domains) != 0 || dsys_getcwd(cwd, 8U) != 0) {
                (void)mark('D');
                return -1;
        }
        if (dsys_chdir(path) != 0) {
                (void)mark('c');
                return -1;
        }
        i = (unsigned int)dsys_getcwd(cwd, 8U);
        if ((int)i != 0) {
                if (cwd[0] == 030002400002UL)
                        (void)mark('e');
                else if (cwd[0] == 030002000002UL)
                        (void)mark('x');
                else
                        (void)mark('g');
                return -1;
        }
        if (cwd[0] != 18UL ||
            cwd[1] != TEST_SIX6('/', 'M', 'O', 'N', 'I', 'T') ||
            cwd[2] != TEST_SIX6('O', 'R', '/', 'D', 'O', 'M') ||
            cwd[3] != TEST_SIX6('A', 'I', 'N', 'S', '/', '2')) {
                (void)mark('{');
                for (i = 0U; i < (unsigned int)cwd[0]; ++i) {
                        word = 1U + i / 6U;
                        shift = 30U - (i % 6U) * 6U;
                        (void)mark((int)(((cwd[word] >> shift) & 077UL) + 040U));
                }
                (void)mark('}');
                (void)mark('m');
                return -1;
        }
        return 0;
}

int
main(int argc, kword_t **argv)
{
        kword_t words[6];
        kword_t status;
        int pid;
        int member;
        int got;
        int read_fd;
        int write_fd;
        unsigned int mode;

        mode = startup_mode(argc, argv);

        if (mode == MEMBER_MODE) {
                if (dsys_procctl(SYS_PROCCTL_GETDOMAIN, 0U) != 2 ||
                    dsys_procctl(SYS_PROCCTL_GETSESSION, 0U) != 1)
                        (void)dsys_exit(061);
                (void)dsys_exit(0);
                return 0;
        }
        if (mode == CHILD_MODE) {
                pid = dsys_getpid();
                if (pid != 2 || dsys_procctl(SYS_PROCCTL_GETDOMAIN, 0U) != 1 ||
                    dsys_procctl(SYS_PROCCTL_GETSESSION, 0U) != 1 ||
                    dsys_procctl(SYS_PROCCTL_NEWDOMAIN, 0U) != pid ||
                    dsys_procctl(SYS_PROCCTL_GETDOMAIN, 0U) != pid ||
                    dsys_procctl(SYS_PROCCTL_GETSESSION, 0U) != 1)
                        (void)dsys_exit(062);
                if (dsys_procctl(SYS_PROCCTL_EVENT_PID,
                    SYS_EVENT_ARG(1U, SYS_EVENT_TERM)) != -1 ||
                    dsys_procctl(SYS_PROCCTL_EVENT_PGRP,
                    SYS_EVENT_ARG(1U, SYS_EVENT_TERM)) != -1)
                        (void)dsys_exit(063);
                if (new_pipe(&read_fd, &write_fd) != 0)
                        (void)dsys_exit(064);
                member = spawn_held(MEMBER_MODE, SYS_RUN_PGRP_INHERIT,
                    write_fd);
                if (member != 3 || wait_zombie_by_eof((unsigned int)member,
                    read_fd, write_fd) != 0)
                        (void)dsys_exit(064);
                if (read_domain_status(words) != 0)
                        (void)dsys_exit(065);
                if (words[0] != 2UL || words[1] < 2UL || words[2] == 0UL ||
                    words[3] != 0UL || words[4] != 0UL || words[5] != 0UL)
                        (void)dsys_exit(066);
                if (domain_dir_has_two() != 0)
                        (void)dsys_exit(067);
                if (domain_cwd_two() != 0)
                        (void)dsys_exit(070);
                (void)dsys_exit(0);
                return 0;
        }

        if (mode != 1U || dsys_getpid() != 1)
                fail('0', 070);
        if (mark('<') != 0)
                fail('1', 071);
        pid = spawn(CHILD_MODE, SYS_RUN_PGRP_NEW);
        if (pid != 2)
                fail('2', 072);
        got = dsys_wait((unsigned int)pid, &status, 0U);
        if (got != pid || SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED)
                fail('3', 073);
        if (SYS_WAIT_STATUS_VALUE(status) == 062U)
                fail('A', 073);
        if (SYS_WAIT_STATUS_VALUE(status) == 063U)
                fail('B', 073);
        if (SYS_WAIT_STATUS_VALUE(status) == 064U)
                fail('C', 073);
        if (SYS_WAIT_STATUS_VALUE(status) == 065U)
                fail('E', 073);
        if (SYS_WAIT_STATUS_VALUE(status) == 066U)
                fail('F', 073);
        if (SYS_WAIT_STATUS_VALUE(status) == 067U)
                fail('G', 073);
        if (SYS_WAIT_STATUS_VALUE(status) == 070U)
                fail('H', 073);
        if (SYS_WAIT_STATUS_VALUE(status) != 0U)
                fail('3', 073);
        if (read_domain_status(words) != 0 || words[0] != 2UL ||
            words[1] != 1UL || words[2] != 0UL || words[3] != 0UL ||
            words[4] != 0UL || words[5] != 0UL)
                fail('4', 074);
        got = dsys_wait(3U, &status, 0U);
        if (got != 3 || SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED)
                fail('5', 075);
        if (read_domain_status(words) == 0)
                fail('6', 076);
        (void)mark('D');
        return dsys_halt();
}
