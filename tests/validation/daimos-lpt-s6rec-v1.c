#include "dsys.h"
#include "../test_sixbit.h"

static kword_t lpt_path[] = {
        9UL,
        TEST_SIX6('/', 'D', 'E', 'V', '/', 'L'),
        TEST_SIX6('P', 'T', '0', ' ', ' ', ' ')
};

int
main(void)
{
        kword_t record[3];
        int fd;

        record[0] = 010000000000UL | 11UL;
        record[1] = TEST_SIX6('H', 'E', 'L', 'L', 'O', ' ');
        record[2] = TEST_SIX6('W', 'O', 'R', 'L', 'D', ' ');
        fd = dsys_open(lpt_path, SYS_O_WRONLY);
        if (fd < 0 || dsys_write_words(fd, record, 3U) != 3 ||
            dsys_close(fd) != 0) {
                (void)dsys_writechar(1, '!');
                (void)dsys_exit(1);
                return 1;
        }
        (void)dsys_writechar(1, 'L');
        (void)dsys_writechar(1, 'P');
        (void)dsys_writechar(1, 'A');
        (void)dsys_writechar(1, 'S');
        (void)dsys_writechar(1, 'S');
        (void)dsys_exit(0);
        return 0;
}
