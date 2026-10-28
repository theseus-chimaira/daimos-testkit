/* v589: corrected SIXBIT CTY0 path; real target character-stream MonitorFS CTY0 statistics test. */
#include "dsys.h"
#include "../test_sixbit.h"
static kword_t cty_stats[] = {
        27UL,
        TEST_SIX6('/','M','O','N','I','T'),
        TEST_SIX6('O','R','/','D','E','V'),
        TEST_SIX6('I','C','E','S','/','C'),
        TEST_SIX6('T','Y','0','/','S','T'),
        TEST_SIX6('A','T','S',' ',' ',' ')
};

static int
read_stats(kword_t *path, kword_t value[3])
{
        unsigned int line;
        unsigned int digits;
        int fd;
        int ch;
        int lf;

        fd = dsys_open(path, SYS_O_RDONLY);
        if (fd < 0) { (void)dsys_writechar(1, 'O'); return -1; }
        for (line = 0U; line < 3U; ++line) {
                value[line] = 0UL;
                digits = 0U;
                for (;;) {
                        ch = dsys_readchar(fd);
                        if (ch < 0) { (void)dsys_writechar(1, 'E'); (void)dsys_writechar(1, '0' + line);
                                (void)dsys_close(fd);
                                return -1;
                        }
                        if (ch == 015) {
                                lf = dsys_readchar(fd);
                                if (lf != 012 || digits != 12U) { (void)dsys_writechar(1, 'L');
                                        (void)dsys_close(fd);
                                        return -1;
                                }
                                break;
                        }
                        if (ch < '0' || ch > '7' || digits >= 12U) { (void)dsys_writechar(1, 'D');
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

int main(void)
{
    kword_t values[3];
    if (read_stats(cty_stats, values) != 0) {
        (void)dsys_writechar(1, '!');
        (void)dsys_halt();
        return 1;
    }
    (void)dsys_writechar(1, 'C');
    (void)dsys_halt();
    return 0;
}
