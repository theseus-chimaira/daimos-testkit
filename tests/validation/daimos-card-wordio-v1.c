#include "dsys.h"
#include "../test_sixbit.h"

#define CARD_WORDS 27U

static kword_t cr_path[] = {
        8UL,
        TEST_SIX6('/', 'D', 'E', 'V', '/', 'C'),
        TEST_SIX6('R', '0', ' ', ' ', ' ', ' ')
};
static kword_t cp_path[] = {
        8UL,
        TEST_SIX6('/', 'D', 'E', 'V', '/', 'C'),
        TEST_SIX6('P', '0', ' ', ' ', ' ', ' ')
};

static void
fail(int ch, int rc)
{
        (void)dsys_writechar(1, '!');
        (void)dsys_writechar(1, ch);
        (void)dsys_exit(rc);
}

int
main(void)
{
        kword_t card[CARD_WORDS];
        int fd;
        int rc;

        fd = dsys_open(cr_path, SYS_O_RDONLY);
        if (fd < 0)
                fail('1', 011);
        rc = dsys_read_words(fd, card, CARD_WORDS);
        if (rc != (int)CARD_WORDS)
                fail('2', 012);
        if ((card[CARD_WORDS - 1U] & 07777UL) != 0UL)
                fail('3', 013);
        if (dsys_close(fd) != 0)
                fail('4', 014);

        fd = dsys_open(cp_path, SYS_O_WRONLY);
        if (fd < 0 || dsys_write_words(fd, card, CARD_WORDS) !=
            (int)CARD_WORDS || dsys_close(fd) != 0)
                fail('5', 015);
        (void)dsys_writechar(1, 'C');
        (void)dsys_writechar(1, 'P');
        (void)dsys_writechar(1, 'A');
        (void)dsys_writechar(1, 'S');
        (void)dsys_writechar(1, 'S');
        (void)dsys_exit(0);
        return 0;
}
