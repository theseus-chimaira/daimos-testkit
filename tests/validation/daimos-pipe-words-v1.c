#include "dsys.h"

#define FIRST_WORDS 20U
#define CONSUME_WORDS 15U
#define SECOND_WORDS 15U

static kword_t first[FIRST_WORDS];
static kword_t second[SECOND_WORDS];
static kword_t got[FIRST_WORDS];

static int
mark(int ch)
{
        return dsys_writechar(1, ch);
}

static void
fail(int ch, int rc)
{
        (void)mark('!');
        (void)mark(ch);
        (void)dsys_exit(rc);
}

static int
new_word_pipe(int *read_fd, int *write_fd)
{
        kword_t pair;

        pair = dsys_pipe_words();
        if (pair == ~0UL)
                return -1;
        *read_fd = (int)((pair >> 18U) & 0777777UL);
        *write_fd = (int)(pair & 0777777UL);
        return *read_fd == *write_fd ? -1 : 0;
}

int
main(void)
{
        kword_t pair;
        unsigned int i;
        int rfd;
        int wfd;
        int n;

        for (i = 0U; i < FIRST_WORDS; ++i)
                first[i] = 0123456000000UL + (kword_t)i;
        for (i = 0U; i < SECOND_WORDS; ++i)
                second[i] = 0765432000000UL + (kword_t)i;

        if (new_word_pipe(&rfd, &wfd) != 0)
                fail('1', 011);
        if (dsys_writechar(wfd, 'X') != -1 || dsys_readchar(rfd) != -1)
                fail('2', 012);
        if (dsys_write_words(wfd, first, FIRST_WORDS) != (int)FIRST_WORDS)
                fail('3', 013);
        n = dsys_read_words(rfd, got, CONSUME_WORDS);
        if (n != (int)CONSUME_WORDS)
                fail('4', 014);
        for (i = 0U; i < CONSUME_WORDS; ++i)
                if (got[i] != first[i])
                        fail('5', 015);

        /* Force both write and read indices through the 26-word ring wrap. */
        if (dsys_write_words(wfd, second, SECOND_WORDS) != (int)SECOND_WORDS)
                fail('6', 016);
        n = dsys_read_words(rfd, got, FIRST_WORDS);
        if (n != (int)FIRST_WORDS)
                fail('7', 017);
        for (i = 0U; i < FIRST_WORDS - CONSUME_WORDS; ++i)
                if (got[i] != first[CONSUME_WORDS + i])
                        fail('8', 020);
        for (i = 0U; i < SECOND_WORDS; ++i)
                if (got[FIRST_WORDS - CONSUME_WORDS + i] != second[i])
                        fail('9', 021);

        if (dsys_close(wfd) != 0 || dsys_read_words(rfd, got, 1U) != 0 ||
            dsys_close(rfd) != 0)
                fail('A', 022);

        /* Character pipes must remain character-only through the word ABI. */
        pair = dsys_pipe();
        if (pair == ~0UL)
                fail('B', 023);
        rfd = (int)((pair >> 18U) & 0777777UL);
        wfd = (int)(pair & 0777777UL);
        if (dsys_write_words(wfd, first, 1U) != -1 ||
            dsys_read_words(rfd, got, 1U) != -1)
                fail('C', 024);
        if (dsys_close(wfd) != 0 || dsys_close(rfd) != 0)
                fail('D', 025);

        if (mark('W') != 0)
                fail('E', 026);
        (void)dsys_exit(0);
        return 0;
}
