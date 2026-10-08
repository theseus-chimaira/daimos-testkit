#include "u.h"
extern void *malloc(unsigned int);
extern void free(void *);

#define BLOCK_WORDS 0200U

static kword_t path[U_PATH_WORDS];

static int
fail(const char *stage, int rc)
{
        (void)u_puts(2, "D6SET1-SCRATCH-FAIL ");
        (void)u_puts(2, stage);
        (void)u_puts(2, " RC=");
        (void)u_put_octal(2, (kword_t)rc, 12U);
        (void)u_crlf(2);
        return 1;
}

int
main(void)
{
        struct vfs_stat st;
        kword_t *block;
        unsigned int pass;
        unsigned int i;
        int fd;
        int rc;

        if (u_s6_pack(path, U_PATH_WORDS, "/SCRATCH/D6SET1.TEST") != 0)
                return fail("PACK", -1);
        block = (kword_t *)malloc(BLOCK_WORDS * sizeof(kword_t));
        if (block == 0)
                return fail("MALLOC", -1);
        fd = dsys_open(path, SYS_O_RDWR | SYS_O_CREAT | SYS_O_TRUNC);
        if (fd < 0)
                return fail("OPEN", fd);
        for (pass = 0U; pass < 2U; ++pass) {
                for (i = 0U; i < BLOCK_WORDS; ++i)
                        block[i] = ((kword_t)(pass + 1U) << 30U) | (kword_t)i;
                rc = dsys_write_words(fd, block, BLOCK_WORDS);
                if (rc != (int)BLOCK_WORDS)
                        return fail("WRITE", rc);
        }
        if (dsys_close(fd) != 0)
                return fail("CLOSE-WRITE", -1);
        if (dsys_stat(path, &st) != 0 || st.size_words != 0400UL)
                return fail("STAT", -1);
        fd = dsys_open(path, SYS_O_RDONLY);
        if (fd < 0)
                return fail("REOPEN", fd);
        for (pass = 0U; pass < 2U; ++pass) {
                for (i = 0U; i < BLOCK_WORDS; ++i)
                        block[i] = 0UL;
                rc = dsys_read_words(fd, block, BLOCK_WORDS);
                if (rc != (int)BLOCK_WORDS)
                        return fail("READ", rc);
                for (i = 0U; i < BLOCK_WORDS; ++i) {
                        kword_t want;
                        want = ((kword_t)(pass + 1U) << 30U) | (kword_t)i;
                        if (block[i] != want)
                                return fail("VERIFY", (int)i);
                }
        }
        if (dsys_close(fd) != 0 || dsys_unlink(path) != 0)
                return fail("CLEANUP", -1);
        free(block);
        (void)u_puts(1, "D6SET1-SCRATCH-PASS");
        (void)u_crlf(1);
        return 0;
}
