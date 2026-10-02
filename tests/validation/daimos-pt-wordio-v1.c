#include "dsys.h"
#include "../test_sixbit.h"

static kword_t ptr_path[] = {
        9UL,
        TEST_SIX6('/', 'D', 'E', 'V', '/', 'P'),
        TEST_SIX6('T', 'R', '0', ' ', ' ', ' ')
};

static kword_t ptp_path[] = {
        9UL,
        TEST_SIX6('/', 'D', 'E', 'V', '/', 'P'),
        TEST_SIX6('T', 'P', '0', ' ', ' ', ' ')
};

static int
mark(const char *s)
{
        unsigned int i;

        for (i = 0U; s[i] != 0; ++i)
                if (dsys_writechar(1, (unsigned char)s[i]) != 0)
                        return -1;
        return 0;
}

static void
mark_oct(unsigned int v)
{
        (void)dsys_writechar(1, '0' + ((v >> 6U) & 07U));
        (void)dsys_writechar(1, '0' + ((v >> 3U) & 07U));
        (void)dsys_writechar(1, '0' + (v & 07U));
}

static void
fail(int ch, int rc)
{
        (void)dsys_writechar(1, '!');
        (void)dsys_writechar(1, ch);
        (void)dsys_exit(rc);
}

static kword_t
full_word(void)
{
        return ((kword_t)001U << 28U) |
            ((kword_t)0177U << 20U) |
            ((kword_t)0200U << 12U) |
            ((kword_t)0377U << 4U);
}

static kword_t
second_full_word(void)
{
        return ((kword_t)021U << 28U) |
            ((kword_t)042U << 20U) |
            ((kword_t)063U << 12U) |
            ((kword_t)0104U << 4U);
}

static kword_t
partial_word(void)
{
        return ((kword_t)021U << 28U) |
            ((kword_t)042U << 20U) |
            ((kword_t)063U << 12U) | 3UL;
}

int
main(void)
{
        kword_t words[2];
        int fd;
        int rc;

        if (mark("PTRREADY") != 0)
                fail('0', 010);
        fd = dsys_open(ptr_path, SYS_O_RDONLY);
        if (fd < 0)
                fail('1', 011);
        rc = dsys_read_words(fd, words, 2U);
        if (rc != 2 || words[0] != full_word() ||
            words[1] != second_full_word()) {
                unsigned int j;
                (void)mark("DBG");
                (void)dsys_writechar(1, '0' + (rc & 7));
                for (j = 0U; j < 2U; ++j) {
                        kword_t w = words[j];
                        unsigned int k;
                        (void)dsys_writechar(1, '/');
                        for (k = 0U; k < 4U; ++k) {
                                mark_oct((unsigned int)((w >> (28U - 8U * k)) & 0377UL));
                                (void)dsys_writechar(1, '.');
                        }
                        mark_oct((unsigned int)(w & 017UL));
                }
                fail('2', 012);
        }
        if (dsys_close(fd) != 0)
                fail('3', 013);


        words[0] = full_word();
        words[1] = partial_word();
        fd = dsys_open(ptp_path, SYS_O_WRONLY);
        if (fd < 0 || dsys_write_words(fd, words, 2U) != 2 ||
            dsys_close(fd) != 0)
                fail('4', 014);

        if (mark("PTPASS") != 0)
                fail('5', 015);
        (void)dsys_exit(0);
        return 0;
}
