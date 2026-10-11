/* D6FS staged-growth cross-block acceptance, C99.
 * Exercises preallocated tail capacity and allocation of new extents. */
#include "u.h"

#define NWORDS 444U
static kword_t path[U_PATH_WORDS];
static kword_t buf[NWORDS];
static kword_t check[64];

static int
fail(const char *where, int rc)
{
        (void)u_puts(1, "D6FS-XBLK-FAIL ");
        (void)u_puts(1, where);
        (void)u_put_octal(1, (kword_t)rc, 12U);
        (void)u_crlf(1);
        return 1;
}

int
main(void)
{
        unsigned int i, start, take, j;
        int fd, rc;

        if (u_s6_pack(path, U_PATH_WORDS, "/CONFIG/XBLKDATA") != 0)
                return fail("PATH", -1);
        for (i = 0; i < NWORDS; ++i)
                buf[i] = 012345600000UL + (kword_t)i;
        fd = dsys_open(path, SYS_O_WRONLY | SYS_O_CREAT | SYS_O_TRUNC);
        if (fd < 0)
                return fail("CREATE", fd);
        rc = dsys_write_words(fd, buf, 120U);
        if (rc != 120 || dsys_close(fd) != 0)
                return fail("SEED", rc);
        fd = dsys_open(path, SYS_O_WRONLY | SYS_O_APPEND);
        if (fd < 0)
                return fail("APPEND1", fd);
        rc = dsys_write_words(fd, buf + 120U, 24U);
        if (rc != 24 || dsys_seek(fd, 0UL, SYS_SEEK_CUR) != 144UL)
                return fail("TAIL-CROSS-BLOCK", rc);
        rc = dsys_write_words(fd, buf + 144U, 300U);
        if (rc != 300 || dsys_seek(fd, 0UL, SYS_SEEK_CUR) != 444UL ||
            dsys_close(fd) != 0)
                return fail("GROW-EXTENTS", rc);
        fd = dsys_open(path, SYS_O_RDONLY);
        if (fd < 0)
                return fail("READ-OPEN", fd);
        for (start = 0U; start < NWORDS; start += take) {
                take = NWORDS - start;
                if (take > 64U)
                        take = 64U;
                rc = dsys_read_words(fd, check, take);
                if (rc != (int)take)
                        return fail("READ-COUNT", rc);
                for (j = 0U; j < take; ++j)
                        if (check[j] != buf[start+j])
                                return fail("CONTENT", (int)(start+j));
        }
        if (dsys_close(fd) != 0)
                return fail("CLOSE", -1);
        (void)u_puts(1, "D6FS-XBLK-PASS");
        (void)u_crlf(1);
        return 0;
}
