#include "dsys.h"
#include "../test_sixbit.h"

static kword_t d6_stats[] = {
        29UL,
        TEST_SIX6('/','M','O','N','I','T'),
        TEST_SIX6('O','R','/','D','E','V'),
        TEST_SIX6('I','C','E','S','/','D'),
        TEST_SIX6('6','S','E','T','0','/'),
        TEST_SIX6('S','T','A','T','S',' ')
};

static kword_t dsk_stats[] = {
        27UL,
        TEST_SIX6('/','M','O','N','I','T'),
        TEST_SIX6('O','R','/','D','E','V'),
        TEST_SIX6('I','C','E','S','/','D'),
        TEST_SIX6('S','K','0','/','S','T'),
        TEST_SIX6('A','T','S',' ',' ',' ')
};

static kword_t source_file[] = {
        16UL,
        TEST_SIX6('/','S','Y','S','T','E'),
        TEST_SIX6('M','/','E','X','E','C'),
        TEST_SIX6('/','D','S','H',' ',' ')
};

static kword_t test_file[] = {
        16UL,
        TEST_SIX6('/','S','Y','S','T','E'),
        TEST_SIX6('M','/','S','T','A','T'),
        TEST_SIX6('T','E','S','T',' ',' ')
};

static void
fail(int ch)
{
        (void)dsys_writechar(1, '!');
        (void)dsys_writechar(1, ch);
        (void)dsys_halt();
        for (;;) { }
}

static void
put_oct(kword_t value)
{
        int shift;

        for (shift = 33; shift >= 0; shift -= 3)
                (void)dsys_writechar(1,
                    '0' + (int)((value >> (unsigned int)shift) & 07UL));
}

static void
dump_pair(char tag, const kword_t before[3], const kword_t after[3])
{
        unsigned int i;

        (void)dsys_writechar(1, tag);
        (void)dsys_writechar(1, ':');
        for (i = 0U; i < 3U; ++i) {
                (void)dsys_writechar(1, ' ');
                put_oct(before[i]);
                (void)dsys_writechar(1, '>');
                put_oct(after[i]);
        }
        (void)dsys_writechar(1, 015);
        (void)dsys_writechar(1, 012);
}

static int
read_stats(kword_t *path, kword_t value[3])
{
        unsigned int line;
        unsigned int digits;
        int fd;
        int ch;
        int lf;

        fd = dsys_open(path, SYS_O_RDONLY);
        if (fd < 3)
                return -1;
        for (line = 0U; line < 3U; ++line) {
                value[line] = 0UL;
                digits = 0U;
                for (;;) {
                        ch = dsys_readchar(fd);
                        if (ch < 0) {
                                (void)dsys_close(fd);
                                return -1;
                        }
                        if (ch == 015) {
                                lf = dsys_readchar(fd);
                                if (lf != 012 || digits != 12U) {
                                        (void)dsys_close(fd);
                                        return -1;
                                }
                                break;
                        }
                        if (ch < '0' || ch > '7' || digits >= 12U) {
                                (void)dsys_close(fd);
                                return -1;
                        }
                        value[line] = (value[line] << 3U) |
                            (kword_t)(unsigned int)(ch - '0');
                        ++digits;
                }
        }
        return dsys_close(fd);
}

static int
exercise_d6fs(void)
{
        kword_t buf[16];
        kword_t word;
        int fd;

        fd = dsys_open(source_file, SYS_O_RDONLY);
        if (fd < 3)
                return -1;
        if (dsys_read_words(fd, buf, 16U) <= 0 || dsys_close(fd) != 0)
                return -1;

        fd = dsys_open(test_file, SYS_O_WRONLY | SYS_O_CREAT | SYS_O_TRUNC);
        if (fd < 3)
                return -1;
        word = TEST_SIX6('T','E','S','T',' ',' ');
        if (dsys_write_words(fd, &word, 1U) != 1 ||
            dsys_close(fd) != 0)
                return -1;
        fd = dsys_open(test_file, SYS_O_RDONLY);
        if (fd < 3)
                return -1;
        if (dsys_read_words(fd, buf, 1U) != 1 || dsys_close(fd) != 0)
                return -1;
        if (dsys_unlink(test_file) != 0)
                return -1;
        return 0;
}

int
main(void)
{
        kword_t d6_before[3];
        kword_t d6_after[3];
        kword_t dsk_before[3];
        kword_t dsk_after[3];

        if (read_stats(d6_stats, d6_before) != 0)
                fail('1');
        if (read_stats(dsk_stats, dsk_before) != 0)
                fail('2');
        if (exercise_d6fs() != 0)
                fail('3');
        if (read_stats(d6_stats, d6_after) != 0)
                fail('4');
        if (read_stats(dsk_stats, dsk_after) != 0)
                fail('5');

        if (d6_after[0] <= d6_before[0]) {
                dump_pair('D', d6_before, d6_after);
                dump_pair('K', dsk_before, dsk_after);
                fail('A');
        }
        if (d6_after[1] <= d6_before[1])
                fail('B');
        if (dsk_after[0] <= dsk_before[0]) {
                dump_pair('D', d6_before, d6_after);
                dump_pair('K', dsk_before, dsk_after);
                fail('C');
        }
        if (dsk_after[1] <= dsk_before[1])
                fail('D');

        (void)dsys_writechar(1, 'S');
        (void)dsys_halt();
        return 0;
}
