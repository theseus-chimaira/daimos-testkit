#include "u.h"

static kword_t path[U_PATH_WORDS];

static int
fail(const char *stage, kword_t value)
{
        (void)u_puts(2, "D6FS-LARGE-INCREMENTAL-FAIL ");
        (void)u_puts(2, stage);
        (void)u_puts(2, " VALUE=");
        (void)u_put_octal(2, value, 12U);
        (void)u_crlf(2);
        return 1;
}

static int
check_word(int fd, unsigned int off)
{
        kword_t got;
        kword_t want;
        int rc;

        want = 012340000000UL | (kword_t)off;
        if (dsys_seek(fd, (kword_t)off, SYS_SEEK_SET) != (kword_t)off)
                return fail("SEEK", (kword_t)off);
        got = 0UL;
        rc = dsys_read_words(fd, &got, 1U);
        if (rc != 1)
                return fail("READ", (kword_t)rc);
        if (got != want)
                return fail("DATA", got);
        return 0;
}

int
main(void)
{
        struct vfs_stat st;
        kword_t word;
        unsigned int i;
        int fd;
        int rc;

        if (u_s6_pack(path, U_PATH_WORDS, "/CONFIG/D6GROW.DATA") != 0)
                return fail("PACK", 0UL);
        fd = dsys_open(path, SYS_O_RDWR | SYS_O_CREAT | SYS_O_TRUNC);
        if (fd < 0)
                return fail("OPEN", (kword_t)fd);

        for (i = 0U; i < 3000U; ++i) {
                word = 012340000000UL | (kword_t)i;
                rc = dsys_write_words(fd, &word, 1U);
                if (rc != 1)
                        return fail("WRITE", (kword_t)i);
        }
        if (dsys_close(fd) != 0)
                return fail("CLOSE", 0UL);
        if (dsys_stat(path, &st) != 0 || st.size_words != 3000UL)
                return fail("STAT", st.size_words);

        fd = dsys_open(path, SYS_O_RDONLY);
        if (fd < 0)
                return fail("REOPEN", (kword_t)fd);
        if (check_word(fd, 0U) != 0 ||
            check_word(fd, 2047U) != 0 ||
            check_word(fd, 2048U) != 0 ||
            check_word(fd, 2999U) != 0)
                return 1;
        (void)dsys_close(fd);
        (void)u_puts(1, "D6FS-LARGE-INCREMENTAL-PASS\r\n");
        return 0;
}
