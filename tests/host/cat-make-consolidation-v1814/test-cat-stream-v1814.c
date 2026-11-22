/* Source-linked S6REC CAT streaming tests.  C89, no guest emulator needed.
 * The mocked word syscalls deliberately use short reads and writes.
 */
#include <stdio.h>
#include <string.h>
#include "text.h"

#define TEST_WORDS 512U
#define TEST_CHARS 2048U
#define TEST_IN 10
#define TEST_OUT 11
#define TEST_TTY 12
#define S6_HEADER (1UL << 30)

static kword_t input[TEST_WORDS];
static kword_t output[TEST_WORDS];
static char tty_output[TEST_CHARS];
static unsigned int input_count;
static unsigned int input_pos;
static unsigned int output_count;
static unsigned int tty_count;
static unsigned int record_count;

int dsys_read_words(int fd, kword_t *buf, unsigned int n)
{
        unsigned int i;
        if (fd != TEST_IN)
                return -1;
        if (input_pos == input_count)
                return 0;
        if (n > 3U) n = 3U;
        if (n > input_count - input_pos)
                n = input_count - input_pos;
        for (i = 0U; i < n; ++i)
                buf[i] = input[input_pos++];
        return (int)n;
}

int dsys_write_words(int fd, kword_t *buf, unsigned int n)
{
        unsigned int i;
        if (fd != TEST_OUT || output_count + n > TEST_WORDS)
                return -1;
        if (n > 2U) n = 2U;
        for (i = 0U; i < n; ++i)
                output[output_count++] = buf[i];
        return (int)n;
}

int dsys_writechar(int fd, int ch)
{
        if (fd != TEST_TTY || tty_count + 1U >= TEST_CHARS)
                return -1;
        tty_output[tty_count++] = (char)ch;
        return 0;
}

int dsys_procctl(unsigned int op, unsigned int arg)
{
        (void)op;
        return arg == TEST_TTY ? 0 : -1;
}

int dsys_close(int fd)
{
        return fd == TEST_IN ? 0 : -1;
}

static void reset_io(void)
{
        input_count = 0U;
        input_pos = 0U;
        output_count = 0U;
        tty_count = 0U;
        record_count = 0U;
        memset(input, 0, sizeof(input));
        memset(output, 0, sizeof(output));
        memset(tty_output, 0, sizeof(tty_output));
}

static char record_char(unsigned int record, unsigned int index)
{
        return (char)('A' + (record + index) % 26U);
}

static void append_record(unsigned int length)
{
        unsigned int i;
        unsigned int record;
        record = record_count++;
        input[input_count++] = S6_HEADER | (kword_t)length;
        for (i = 0U; i < length; ++i) {
                unsigned int slot = i % 6U;
                unsigned int shift = 30U - 6U * slot;
                unsigned int wi = input_count + i / 6U;
                unsigned int ch = (unsigned int)record_char(record, i);
                input[wi] |= (kword_t)(ch - 040U) << shift;
        }
        input_count += (length + 5U) / 6U;
}

static int test_words(void)
{
        struct u_text_reader r;
        unsigned int i;
        int rc;
        reset_io();
        append_record(0U);
        append_record(7U);
        append_record(258U);
        append_record(259U);
        append_record(1000U);
        if (u_text_open_fd(&r, TEST_IN) != 0 ||
            u_text_sink_attach(TEST_OUT) != 0)
                return 1;
        for (i = 0U; i < record_count; ++i) {
                rc = u_text_copy_line(&r, TEST_OUT);
                if (rc != 1) {
                        fprintf(stderr, "file record %u: got %d\n", i, rc);
                        return 1;
                }
        }
        rc = u_text_copy_line(&r, TEST_OUT);
        u_text_close(&r);
        if (rc != U_TEXT_EOF || u_text_sink_detach() != 0 ||
            output_count != input_count ||
            memcmp(input, output,
                input_count * sizeof(input[0])) != 0)
                return 1;
        puts("PASS v1814: 0/7/258/259/1000-char S6REC records preserved");
        return 0;
}

static int test_tty(void)
{
        struct u_text_reader r;
        unsigned int i;
        reset_io();
        append_record(1000U);
        if (u_text_open_fd(&r, TEST_IN) != 0 ||
            u_text_copy_line(&r, TEST_TTY) != 1 ||
            u_text_copy_line(&r, TEST_TTY) != U_TEXT_EOF ||
            tty_count != 1002U ||
            tty_output[1000] != '\r' || tty_output[1001] != '\n')
                return 1;
        for (i = 0U; i < 1000U; ++i)
                if (tty_output[i] != record_char(0U, i))
                        return 1;
        u_text_close(&r);
        puts("PASS v1814: long TTY record emitted by character I/O");
        return 0;
}

static int test_malformed(void)
{
        struct u_text_reader r;
        reset_io();
        input[0] = (2UL << 30) | 1UL;
        input_count = 1U;
        if (u_text_open_fd(&r, TEST_IN) != 0 ||
            u_text_copy_line(&r, TEST_OUT) != U_TEXT_ERROR ||
            output_count != 0U)
                return 1;
        u_text_close(&r);
        reset_io();
        input[0] = S6_HEADER | 20UL;
        input[1] = 0123456UL;
        input_count = 2U;
        if (u_text_open_fd(&r, TEST_IN) != 0 ||
            u_text_copy_line(&r, TEST_OUT) != U_TEXT_ERROR)
                return 1;
        u_text_close(&r);
        puts("PASS v1814: invalid type and truncated payload rejected");
        return 0;
}

int main(void)
{
        if (test_words() || test_tty() || test_malformed()) {
                fputs("FAIL v1814: CAT S6REC stream\n", stderr);
                return 1;
        }
        return 0;
}
