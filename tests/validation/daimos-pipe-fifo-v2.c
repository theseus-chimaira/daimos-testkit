#include "dsys.h"
#include "../test_sixbit.h"

#define CHILD_WRITER_MODE   0131U
#define CHILD_READER_MODE   0132U
#define BURN_COUNT          0200000U
#define RUN_PATH_WORDS      3U
#define RUN_ARG_WORDS       2U
#define RUN_PATH_OFF        SYS_RUN_V2_FIXED_WORDS
#define RUN_ARG0_OFF        (RUN_PATH_OFF + RUN_PATH_WORDS)
#define RUN_ARG1_OFF        (RUN_ARG0_OFF + RUN_PATH_WORDS)
#define RUN_MAP_OFF         (RUN_ARG1_OFF + RUN_ARG_WORDS)
#define RUN_BLOCK_WORDS     (RUN_MAP_OFF + 2U)

static kword_t init_path[] = {
        12UL,
        TEST_SIX6('/', 'S', 'Y', 'S', 'T', 'E'),
        TEST_SIX6('M', '/', 'I', 'N', 'I', 'T')
};

static volatile kword_t burn_word;

static kword_t temp_fifo[] = {
        10UL,
        TEST_SIX6('/', 'T', 'E', 'M', 'P', '/'),
        TEST_SIX6('F', 'I', 'F', 'O', ' ', ' ')
};

static kword_t temp_fifo2[] = {
        10UL,
        TEST_SIX6('/', 'T', 'E', 'M', 'P', '/'),
        TEST_SIX6('F', 'I', 'F', '2', ' ', ' ')
};

static kword_t temp_dir[] = {
        5UL,
        TEST_SIX6('/', 'T', 'E', 'M', 'P', ' ')
};

static kword_t d6_fifo[] = {
        6UL,
        TEST_SIX6('/', 'D', 'F', 'I', 'F', 'O')
};

static void
burn(void)
{
        unsigned int i;

        for (i = 0U; i < BURN_COUNT; ++i)
                burn_word = (burn_word + (kword_t)i + 1UL) & 0777777777777UL;
}

static int
mark(int ch)
{
        return dsys_writechar(1, ch);
}

static int
write_word(int fd, kword_t word)
{
        return dsys_write_words(fd, &word, 1U) == 1 ? 0 : -1;
}

static int
read_word(int fd, kword_t expected)
{
        kword_t word;

        return dsys_read_words(fd, &word, 1U) == 1 && word == expected ?
            0 : -1;
}

static void
fail(int ch, int rc)
{
        (void)mark('!');
        (void)mark(ch);
        (void)dsys_exit(rc);
}

static int
spawn(unsigned int mode)
{
        kword_t block[RUN_BLOCK_WORDS];
        struct sys_run_v2 *run;
        unsigned int i;
        int mode_ch;

        for (i = 0U; i < RUN_BLOCK_WORDS; ++i)
                block[i] = 0UL;
        run = (struct sys_run_v2 *)block;
        run->flags = SYS_RUN_PGRP_INHERIT;
        run->pgrp = 0UL;
        run->fdmap_count = 2UL;
        run->argc = 2UL;
        run->envc = 0UL;
        for (i = 0U; i < RUN_PATH_WORDS; ++i) {
                block[RUN_PATH_OFF + i] = init_path[i];
                block[RUN_ARG0_OFF + i] = init_path[i];
        }
        mode_ch = mode == CHILD_WRITER_MODE ? 'W' : 'R';
        block[RUN_ARG1_OFF] = 1UL;
        block[RUN_ARG1_OFF + 1U] =
            TEST_SIX6(mode_ch, ' ', ' ', ' ', ' ', ' ');
        block[RUN_MAP_OFF] = SYS_RUN_FD_MAP(1U, 1U);
        block[RUN_MAP_OFF + 1U] = SYS_RUN_FD_MAP(2U, 2U);
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
        if (ch == 'W') return CHILD_WRITER_MODE;
        if (ch == 'R') return CHILD_READER_MODE;
        return 0U;
}

static int
wait_exit(int pid, unsigned int code)
{
        kword_t status;
        int got;

        status = 0UL;
        got = dsys_wait((unsigned int)pid, &status, 0U);
        if (got != pid || SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status) != code)
                return -1;
        return 0;
}

int
main(int argc, kword_t **argv)
{
        struct vfs_stat st;
        int fd;
        int fd2;
        int pid;
        unsigned int mode;

        mode = startup_mode(argc, argv);

        if (mode == CHILD_WRITER_MODE) {
                burn();
                fd = dsys_open(temp_fifo, SYS_O_WRONLY);
                if (fd < 0 || write_word(fd, 0123456000001UL) != 0 ||
                    dsys_close(fd) != 0)
                        (void)dsys_exit(061);
                (void)dsys_exit(051);
                return 051;
        }
        if (mode == CHILD_READER_MODE) {
                burn();
                fd = dsys_open(temp_fifo, SYS_O_RDONLY);
                if (fd < 0 || read_word(fd, 0123456000002UL) != 0 ||
                    dsys_close(fd) != 0)
                        (void)dsys_exit(062);
                (void)dsys_exit(052);
                return 052;
        }
        if (mode != 1U)
                fail('0', 010);

        if (dsys_mkfifo(temp_fifo, 0640U) != 0)
                fail('1', 011);
        if (dsys_stat(temp_fifo, &st) != 0)
                fail('s', 012);
        if (st.type != VFS_TYPE_FIFO)
                fail((int)('0' + st.type), 012);
        if (st.mode != 0640U)
                fail('m', 012);
        if (st.size_words != 0UL)
                fail('w', 012);

        /* Reader open must sleep until the delayed writer opens the FIFO. */
        pid = spawn(CHILD_WRITER_MODE);
        if (pid <= 1)
                fail('3', 013);
        fd = dsys_open(temp_fifo, SYS_O_RDONLY);
        if (fd < 0 || read_word(fd, 0123456000001UL) != 0 ||
            dsys_read_words(fd, (kword_t *)&st, 1U) != 0 || dsys_close(fd) != 0 ||
            wait_exit(pid, 051U) != 0)
                fail('4', 014);

        /* Writer open must sleep until the delayed reader opens the FIFO. */
        pid = spawn(CHILD_READER_MODE);
        if (pid <= 1)
                fail('5', 015);
        fd = dsys_open(temp_fifo, SYS_O_WRONLY);
        if (fd < 0 || write_word(fd, 0123456000002UL) != 0 ||
            dsys_close(fd) != 0 || wait_exit(pid, 052U) != 0)
                fail('6', 016);

        /* O_RDWR is a self-paired endpoint and never waits for a peer. */
        fd = dsys_open(temp_fifo, SYS_O_RDWR);
        if (fd < 0 || write_word(fd, 0123456000003UL) != 0 ||
            read_word(fd, 0123456000003UL) != 0)
                fail('7', 017);

        /* A second open of the same persistent FIFO joins the live stream. */
        fd2 = dsys_open(temp_fifo, SYS_O_RDWR);
        if (fd2 < 0 || write_word(fd, 0123456000004UL) != 0 ||
            read_word(fd2, 0123456000004UL) != 0)
                fail('8', 020);
        if (dsys_close(fd2) != 0)
                fail('9', 021);

        /* Rename preserves vnode identity and therefore the live association. */
        if (dsys_rename(temp_fifo, temp_fifo2) != 0)
                fail('A', 022);
        fd2 = dsys_open(temp_fifo2, SYS_O_RDWR);
        if (fd2 < 0 || write_word(fd, 0123456000005UL) != 0 ||
            read_word(fd2, 0123456000005UL) != 0 || dsys_close(fd2) != 0)
                fail('B', 023);

        /* Unlink detaches the old live object before an FCB/node can be reused. */
        if (write_word(fd, 0123456000006UL) != 0 || dsys_unlink(temp_fifo2) != 0 ||
            dsys_mkfifo(temp_fifo2, 0600U) != 0)
                fail('C', 024);
        fd2 = dsys_open(temp_fifo2, SYS_O_RDWR);
        if (fd2 < 0 || write_word(fd2, 0123456000007UL) != 0 ||
            read_word(fd2, 0123456000007UL) != 0 ||
            read_word(fd, 0123456000006UL) != 0)
                fail('D', 025);

        /* The mount remains busy while the newly named FIFO has live refs. */
        if (dsys_unmount(temp_dir) != -1)
                fail('E', 026);
        if (dsys_close(fd2) != 0 || dsys_close(fd) != 0)
                fail('F', 027);
        if (dsys_stat(temp_fifo2, &st) != 0 || st.type != VFS_TYPE_FIFO)
                fail('G', 030);

        /* D6FS persists the FIFO type as a zero-data special file. */
        if (dsys_mkfifo(d6_fifo, 0620U) != 0 ||
            dsys_stat(d6_fifo, &st) != 0 || st.type != VFS_TYPE_FIFO ||
            st.mode != 0620U || st.size_words != 0UL)
                fail('H', 031);
        fd = dsys_open(d6_fifo, SYS_O_RDWR);
        if (fd < 0 || write_word(fd, 0123456000010UL) != 0 ||
            read_word(fd, 0123456000010UL) != 0 || dsys_close(fd) != 0)
                fail('I', 032);
        if (dsys_unlink(d6_fifo) != 0)
                fail('J', 033);

        if (mark('F') != 0)
                fail('K', 034);
        (void)dsys_exit(0);
        return 0;
}
