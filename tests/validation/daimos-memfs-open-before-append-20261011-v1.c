/* MEMFS O_APPEND: two preopened descriptors must reserve distinct EOF ranges.
 * This catches the old open-time EOF snapshot deterministically, without
 * relying on scheduler timing or background DSH worker behavior.  C99. */
#include "u.h"

static kword_t path[U_PATH_WORDS];
static kword_t actual[5];

static int
fail(const char *where, int rc)
{
        (void)u_puts(1, "MEMFS-APP2-FAIL ");
        (void)u_puts(1, where);
        (void)u_puts(1, " RC=");
        (void)u_put_octal(1, (kword_t)rc, 12U);
        (void)u_crlf(1);
        return 1;
}

int
main(void)
{
        static const kword_t values[4] = {
                000111111111111UL, 000222222222222UL,
                000333333333333UL, 000444444444444UL
        };
        int first;
        int second;
        int duplicate;
        int fd;
        int rc;
        kword_t cursor;
        unsigned int i;

        if (u_s6_pack(path, U_PATH_WORDS, "/TEMP/APP2DATA") != 0)
                return fail("PATH", -1);
        fd = dsys_open(path, SYS_O_WRONLY | SYS_O_CREAT | SYS_O_TRUNC);
        if (fd < 0)
                return fail("CREATE", fd);
        rc = dsys_write_words(fd, (kword_t *)&values[0], 1U);
        if (rc != 1 || dsys_close(fd) != 0)
                return fail("SEED", rc);

        /* Both opens see identical file size; the old implementation would
         * overwrite FIRST with SECOND instead of appending after it. */
        first = dsys_open(path, SYS_O_WRONLY | SYS_O_APPEND);
        second = dsys_open(path, SYS_O_WRONLY | SYS_O_APPEND);
        if (first < 0 || second < 0)
                return fail("OPEN-PAIR", -1);
        if (dsys_seek(second, 0UL, SYS_SEEK_SET) != 0UL)
                return fail("SEEK-OVERRIDE", -1);
        rc = dsys_write_words(first, (kword_t *)&values[1], 1U);
        if (rc != 1 || dsys_seek(first, 0UL, SYS_SEEK_CUR) != 2UL)
                return fail("FIRST-APPEND", rc);
        rc = dsys_write_words(second, (kword_t *)&values[2], 1U);
        if (rc != 1)
                return fail("SECOND-APPEND", rc);
        cursor = dsys_seek(second, 0UL, SYS_SEEK_CUR);
        if (cursor != 3UL)
                return fail("SECOND-CURSOR", (int)cursor);

        /* Duplicating an append descriptor must retain its append intent. */
        duplicate = dsys_dup(first);
        if (duplicate < 0)
                return fail("DUP", duplicate);
        rc = dsys_write_words(duplicate, (kword_t *)&values[3], 1U);
        if (rc != 1 || dsys_seek(duplicate, 0UL, SYS_SEEK_CUR) != 4UL)
                return fail("DUP-APPEND", rc);
        if (dsys_close(duplicate) != 0 || dsys_close(first) != 0 ||
            dsys_close(second) != 0)
                return fail("CLOSE", -1);

        fd = dsys_open(path, SYS_O_RDONLY);
        if (fd < 0)
                return fail("REOPEN", fd);
        rc = dsys_read_words(fd, actual, 5U);
        if (rc != 4)
                return fail("SIZE", rc);
        for (i = 0U; i < 4U; ++i)
                if (actual[i] != values[i])
                        return fail("CONTENT", (int)i);
        if (dsys_close(fd) != 0)
                return fail("READ-CLOSE", -1);
        (void)u_puts(1, "MEMFS-APP2-PASS");
        (void)u_crlf(1);
        return 0;
}
