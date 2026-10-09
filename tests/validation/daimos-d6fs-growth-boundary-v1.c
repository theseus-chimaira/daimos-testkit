#include "u.h"

#define TEST_WORDS 010000U

static kword_t path[U_PATH_WORDS];

static int
fail(const char *stage, unsigned int at, int rc)
{
        (void)u_puts(2, "D6FS-GROWTH-FAIL ");
        (void)u_puts(2, stage);
        (void)u_puts(2, " AT=");
        (void)u_put_octal(2, (kword_t)at, 6U);
        (void)u_puts(2, " RC=");
        (void)u_put_octal(2, (kword_t)rc, 12U);
        (void)u_crlf(2);
        return 1;
}

int
main(void)
{
        kword_t word;
        kword_t got;
        unsigned int i;
        int fd;
        int rc;

        if (u_s6_pack(path, U_PATH_WORDS, "/CONFIG/D6GROW.TEST") != 0)
                return fail("PACK", 0U, -1);
        fd = dsys_open(path, SYS_O_RDWR | SYS_O_CREAT | SYS_O_TRUNC);
        if (fd < 0)
                return fail("OPEN", 0U, fd);

        for (i = 0U; i < TEST_WORDS; ++i) {
                word = 0123400000000UL | (kword_t)i;
                rc = dsys_write_words(fd, &word, 1U);
                if (rc != 1) {
                        (void)dsys_close(fd);
                        return fail("WRITE", i, rc);
                }
        }

        if (dsys_seek(fd, 0UL, SYS_SEEK_SET) == (kword_t)-1) {
                (void)dsys_close(fd);
                return fail("SEEK", 0U, -1);
        }
        for (i = 0U; i < TEST_WORDS; ++i) {
                got = 0UL;
                rc = dsys_read_words(fd, &got, 1U);
                if (rc != 1) {
                        (void)dsys_close(fd);
                        return fail("READ", i, rc);
                }
                word = 0123400000000UL | (kword_t)i;
                if (got != word) {
                        (void)dsys_close(fd);
                        return fail("VERIFY", i, 0);
                }
        }
        if (dsys_close(fd) != 0)
                return fail("CLOSE", TEST_WORDS, -1);
        (void)u_puts(1, "D6FS-GROWTH-PASS");
        (void)u_crlf(1);
        return 0;
}
