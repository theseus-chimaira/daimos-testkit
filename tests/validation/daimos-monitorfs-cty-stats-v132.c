/*
 * Validate the MonitorFS CTY0 statistics character stream.
 * The kernel publishes three fixed-width octal lines over READCHAR,
 * not S6REC word records. The ordinary CAT utility cannot read it.
 */
#include "dsys.h"
#include "test_sixbit.h"

static kword_t cty_stats_v132[] = {
        27UL,
        TEST_SIX6('/', 'M', 'O', 'N', 'I', 'T'),
        TEST_SIX6('O', 'R', '/', 'D', 'E', 'V'),
        TEST_SIX6('I', 'C', 'E', 'S', '/', 'C'),
        TEST_SIX6('T', 'Y', '0', '/', 'S', 'T'),
        TEST_SIX6('A', 'T', 'S', ' ', ' ', ' ')
};

static void
fail_v132(int ch)
{
        (void)dsys_writechar(1, '!');
        (void)dsys_writechar(1, ch);
        (void)dsys_halt();
        for (;;) { }
}

static int
read_cty_stats_v132(kword_t counts[3])
{
        unsigned int line;
        unsigned int digit;
        int fd;
        int ch;

        fd = dsys_open(cty_stats_v132, SYS_O_RDONLY);
        if (fd < 3)
                return -1;
        for (line = 0U; line < 3U; ++line) {
                counts[line] = 0UL;
                for (digit = 0U; digit < 12U; ++digit) {
                        ch = dsys_readchar(fd);
                        if (ch < '0' || ch > '7') {
                                (void)dsys_close(fd);
                                return -1;
                        }
                        counts[line] = (counts[line] << 3U) |
                            (kword_t)(unsigned int)(ch - '0');
                }
                if (dsys_readchar(fd) != 015 ||
                    dsys_readchar(fd) != 012) {
                        (void)dsys_close(fd);
                        return -1;
                }
        }
        if (dsys_readchar(fd) != -2) {
                (void)dsys_close(fd);
                return -1;
        }
        return dsys_close(fd);
}

int
main(void)
{
        kword_t before[3];
        kword_t after[3];

        (void)dsys_writechar(1, '<');
        if (read_cty_stats_v132(before) != 0)
                fail_v132('1');
        if (dsys_writechar(1, 'C') != 0)
                fail_v132('2');
        if (read_cty_stats_v132(after) != 0)
                fail_v132('3');
        if (after[0] < before[0] || after[1] <= before[1] ||
            after[2] < before[2])
                fail_v132('4');
        (void)dsys_writechar(1, 'S');
        (void)dsys_halt();
        return 0;
}
