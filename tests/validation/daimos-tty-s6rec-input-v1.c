#include "dsys.h"
#include "../test_sixbit.h"

#define S6REC_TYPE_SHIFT 30U
#define S6REC_LEN_MASK   077777777UL
#define S6REC_TEXT       1U

static kword_t buf[22];

static int
mark(int ch)
{
        return dsys_writechar(1, ch);
}

static void
phase(int ch)
{
        (void)mark('<');
        (void)mark(ch);
}

static void
fail(int ch, int rc)
{
        (void)mark('!');
        (void)mark(ch);
        (void)dsys_exit(rc);
}

static int
record_is(unsigned int len, kword_t first)
{
        return (unsigned int)((buf[0] >> S6REC_TYPE_SHIFT) & 077UL) ==
            S6REC_TEXT && (buf[0] & S6REC_LEN_MASK) == (kword_t)len &&
            (len == 0U || buf[1] == first);
}

int
main(void)
{
        int rc;

        if (dsys_procctl(SYS_PROCCTL_TTY_ATTACH, 0U) != 0 ||
            dsys_procctl(SYS_PROCCTL_TTY_SETMODE,
            SYS_TTY_MODE_COOKED) != (int)SYS_TTY_MODE_COOKED)
                fail('0', 010);

        phase('A');
        rc = dsys_read_words(0, buf, 22U);
        if (rc != 2 || !record_is(3U,
            TEST_SIX6('A', 'B', 'C', ' ', ' ', ' ')))
                fail('1', 011);

        /* The small-buffer failure must leave the READY canonical line intact. */
        phase('B');
        rc = dsys_read_words(0, buf, 1U);
        if (rc != -1)
                fail('2', 012);
        rc = dsys_read_words(0, buf, 22U);
        if (rc != 2 || !record_is(5U,
            TEST_SIX6('H', 'E', 'L', 'L', 'O', ' ')))
                fail('3', 013);

        phase('C');
        rc = dsys_read_words(0, buf, 22U);
        if (rc != 1 || !record_is(0U, 0UL))
                fail('4', 014);

        phase('D');
        rc = dsys_read_words(0, buf, 22U);
        if (rc != 0)
                fail('5', 015);

        phase('E');
        rc = dsys_read_words(0, buf, 22U);
        if (rc != 2 || !record_is(1U,
            TEST_SIX6('Z', ' ', ' ', ' ', ' ', ' ')))
                fail('6', 016);

        if (dsys_procctl(SYS_PROCCTL_TTY_SETMODE, SYS_TTY_MODE_RAW) !=
            (int)SYS_TTY_MODE_RAW || dsys_read_words(0, buf, 22U) != -1)
                fail('7', 017);
        phase('P');
        (void)dsys_exit(0);
        return 0;
}
