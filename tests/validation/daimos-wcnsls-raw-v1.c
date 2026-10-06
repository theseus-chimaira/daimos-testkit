#include "dsys.h"
#include "wcnsls.h"
#include "../test_sixbit.h"

static kword_t wcnsls_path[] = {
        11UL,
        TEST_SIX6('/', 'D', 'E', 'V', '/', 'W'),
        TEST_SIX6('C', 'N', 'S', 'L', 'S', ' ')
};

static int
mark(int ch)
{
        return dsys_writechar(1, ch);
}

int
main(void)
{
        kword_t ops[4];
        kword_t input;
        int fd;

        if (mark('<') != 0)
                (void)dsys_exit(1);
        fd = dsys_open(wcnsls_path, SYS_O_RDWR);
        if (fd < 0) {
                (void)mark('O');
                (void)dsys_exit(2);
        }
        if (dsys_rtctl(SYS_RTCTL_ENABLE) != 0) {
                (void)mark('R');
                (void)dsys_exit(3);
        }

        ops[0] = WCNSLS_RAW_CONO_WORD(WCNSLS_CO_SPACEWAR |
            WCNSLS_CO_RED_ENABLE | WCNSLS_CO_RED_MAX);
        ops[1] = WCNSLS_RAW_DATAO(WCNSLS_COORD(0123U, 0456U));
        ops[2] = WCNSLS_RAW_CONO_WORD(WCNSLS_CO_SPACEWAR |
            WCNSLS_CO_GREEN_ENABLE | WCNSLS_CO_GREEN_MAX);
        ops[3] = WCNSLS_RAW_DATAO(WCNSLS_COORD(0321U, 0654U));
        if (dsys_write_words(fd, ops, 4U) != 4) {
                (void)mark('W');
                (void)dsys_exit(4);
        }
        if (dsys_read_words(fd, &input, 1U) != 1 || input == 0UL) {
                (void)mark('I');
                (void)dsys_exit(5);
        }
        if (dsys_rtctl(SYS_RTCTL_DISABLE) != 0 || dsys_close(fd) != 0) {
                (void)mark('C');
                (void)dsys_exit(6);
        }
        (void)mark('P');
        (void)dsys_halt();
        return 0;
}
