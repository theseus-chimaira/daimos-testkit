#include "dsys.h"
#include "../test_sixbit.h"

#define CHILD_MODE           0271U
#define CHILD_STATUS         061U
#define RUN_PATH_WORDS       3U
#define RUN_ARG_WORDS        2U
#define RUN_PATH_OFF         SYS_RUN_V2_FIXED_WORDS
#define RUN_ARG0_OFF         (RUN_PATH_OFF + RUN_PATH_WORDS)
#define RUN_ARG1_OFF         (RUN_ARG0_OFF + RUN_PATH_WORDS)
#define RUN_MAP_OFF          (RUN_ARG1_OFF + RUN_ARG_WORDS)
#define RUN_BLOCK_WORDS      (RUN_MAP_OFF + 4U)

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

static int
arg_is_char(const kword_t *arg, int ch)
{
        unsigned int packed;

        if (arg == 0 || (arg[0] & 0777777UL) != 1UL)
                return 0;
        packed = (unsigned int)((arg[1] >> 30U) & 077UL);
        return packed + 040U == (unsigned int)ch;
}

static void
fail(int ch, int rc)
{
        (void)mark('!');
        (void)mark(ch);
        (void)dsys_exit(rc);
}

static int
spawn_child(int hold_fd)
{
        kword_t block[RUN_BLOCK_WORDS];
        struct sys_run_v2 *run;
        unsigned int i;

        for (i = 0U; i < RUN_BLOCK_WORDS; ++i)
                block[i] = 0UL;
        run = (struct sys_run_v2 *)block;
        run->flags = SYS_RUN_PGRP_INHERIT;
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
            TEST_SIX6('C', ' ', ' ', ' ', ' ', ' ');
        block[RUN_MAP_OFF] = SYS_RUN_FD_MAP(0U, 0U);
        block[RUN_MAP_OFF + 1U] = SYS_RUN_FD_MAP(1U, 1U);
        block[RUN_MAP_OFF + 2U] = SYS_RUN_FD_MAP(2U, 2U);
        block[RUN_MAP_OFF + 3U] = SYS_RUN_FD_MAP(3U, (unsigned int)hold_fd);
        run->version_words = SYS_RUN_HEADER(SYS_RUN_VERSION_2,
            RUN_BLOCK_WORDS);
        return dsys_run(run);
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

        if (dsys_close(write_fd) != 0 || dsys_read_words(read_fd, &word, 1U) != 0 ||
            dsys_close(read_fd) != 0)
                return -1;
        if (dsys_procinfo(pid, &info) != 0 || info.state != 4U)
                return -1;
        return 0;
}

static int
read_exact(kword_t *path, const char *expected)
{
        struct vfs_stat st;
        kword_t words[8];
        kword_t header;
        kword_t packed;
        unsigned int i;
        unsigned int slot;
        unsigned int shift;
        int fd;
        int n;

        if (dsys_stat(path, &st) != 0)
                return 8;
        fd = dsys_open(path, SYS_O_RDONLY);
        if (fd < 3)
                return 1;
        n = dsys_read_words(fd, words, 8U);
        if (n < 1) {
                (void)dsys_close(fd);
                return 2;
        }
        header = words[0];
        if (((header >> 30U) & 077UL) != 1UL)
                return 3;
        packed = 0UL;
        slot = 6U;
        for (i = 0U; expected[i] != '\0'; ++i) {
                if ((kword_t)i >= (header & 077777777UL)) {
                        (void)dsys_close(fd);
                        return 4;
                }
                if (slot == 6U) {
                        if (1U + i / 6U >= (unsigned int)n) {
                                (void)dsys_close(fd);
                                return 5;
                        }
                        packed = words[1U + i / 6U];
                        slot = 0U;
                }
                shift = 30U - slot * 6U;
                if (((packed >> shift) & 077UL) + 040UL !=
                    (unsigned int)expected[i]) {
                        (void)dsys_close(fd);
                        return 6;
                }
                ++slot;
        }
        if ((header & 077777777UL) != (kword_t)i ||
            dsys_read_words(fd, words, 8U) != 0 || dsys_close(fd) != 0)
                return 7;
        return 0;
}

int
main(int argc, kword_t **argv)
{
        static kword_t state10[] = {
                14UL,
                TEST_SIX6('/', 'P', 'R', 'O', 'C', '/'),
                TEST_SIX6('1', '0', '/', 'S', 'T', 'A'),
                TEST_SIX6('T', 'E', ' ', ' ', ' ', ' ')
        };
        kword_t status;
        int pid;
        int i;
        int read_fd;
        int write_fd;
        unsigned int mode;

        mode = 1U;
        if (argc == 2 && argv != 0 && arg_is_char(argv[1], 'C'))
                mode = CHILD_MODE;
        if (mode == CHILD_MODE) {
                (void)dsys_exit(CHILD_STATUS);
                return CHILD_STATUS;
        }
        if (mode != 1U || dsys_getpid() != 1)
                fail('0', 010);
        if (mark('<') != 0)
                fail('1', 011);

        for (i = 2; i <= 10; ++i) {
                if (new_pipe(&read_fd, &write_fd) != 0)
                        fail('A', 012);
                pid = spawn_child(write_fd);
                if (pid != i) {
                        (void)mark(i < 10 ? '0' + i : 'A');
                        fail('B', 012);
                }
                if (wait_zombie_by_eof((unsigned int)pid, read_fd,
                    write_fd) != 0)
                        fail('C', 012);
        }

        i = read_exact(state10, "ZOMB");
        if (i != 0)
                fail('0' + i, 013);

        for (i = 2; i <= 10; ++i) {
                pid = dsys_wait((unsigned int)i, &status, 0U);
                if (pid != i || SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
                    SYS_WAIT_STATUS_VALUE(status) != CHILD_STATUS)
                        fail('4', 014);
        }

        (void)mark('P');
        (void)dsys_exit(0);
        return 0;
}
