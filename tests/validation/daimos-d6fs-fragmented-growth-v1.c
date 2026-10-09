#include "u.h"

#define FILE_COUNT 4U
#define ROUNDS 010U
#define BLOCK_WORDS 0200U

static kword_t path[U_PATH_WORDS];
static kword_t block[BLOCK_WORDS];

static int
fail(const char *stage, unsigned int file, unsigned int round, int rc)
{
        (void)u_puts(2, "D6FS-FRAG-FAIL ");
        (void)u_puts(2, stage);
        (void)u_puts(2, " FILE=");
        (void)u_put_octal(2, (kword_t)file, 2U);
        (void)u_puts(2, " ROUND=");
        (void)u_put_octal(2, (kword_t)round, 2U);
        (void)u_puts(2, " RC=");
        (void)u_put_octal(2, (kword_t)rc, 12U);
        (void)u_crlf(2);
        return 1;
}

static int
make_path(unsigned int file)
{
        static const char names[FILE_COUNT][18] = {
                "/CONFIG/D6FRAG.A",
                "/CONFIG/D6FRAG.B",
                "/CONFIG/D6FRAG.C",
                "/CONFIG/D6FRAG.D"
        };

        return u_s6_pack(path, U_PATH_WORDS, names[file]);
}

int
main(void)
{
        int fd[FILE_COUNT];
        unsigned int file;
        unsigned int round;
        unsigned int i;
        int rc;

        for (file = 0U; file < FILE_COUNT; ++file) {
                if (make_path(file) != 0)
                        return fail("PACK", file, 0U, -1);
                fd[file] = dsys_open(path,
                    SYS_O_RDWR | SYS_O_CREAT | SYS_O_TRUNC);
                if (fd[file] < 0)
                        return fail("OPEN", file, 0U, fd[file]);
        }

        for (round = 0U; round < ROUNDS; ++round) {
                for (file = 0U; file < FILE_COUNT; ++file) {
                        for (i = 0U; i < BLOCK_WORDS; ++i)
                                block[i] = ((kword_t)(file + 1U) << 30U) |
                                    ((kword_t)round << 18U) | (kword_t)i;
                        rc = dsys_write_words(fd[file], block, BLOCK_WORDS);
                        if (rc != (int)BLOCK_WORDS)
                                return fail("WRITE", file, round, rc);
                }
        }

        for (file = 0U; file < FILE_COUNT; ++file) {
                if (dsys_seek(fd[file], 0UL, SYS_SEEK_SET) == (kword_t)-1)
                        return fail("SEEK", file, 0U, -1);
                for (round = 0U; round < ROUNDS; ++round) {
                        for (i = 0U; i < BLOCK_WORDS; ++i)
                                block[i] = 0UL;
                        rc = dsys_read_words(fd[file], block, BLOCK_WORDS);
                        if (rc != (int)BLOCK_WORDS)
                                return fail("READ", file, round, rc);
                        for (i = 0U; i < BLOCK_WORDS; ++i) {
                                kword_t want;

                                want = ((kword_t)(file + 1U) << 30U) |
                                    ((kword_t)round << 18U) | (kword_t)i;
                                if (block[i] != want)
                                        return fail("VERIFY", file, round,
                                            (int)i);
                        }
                }
                if (dsys_close(fd[file]) != 0)
                        return fail("CLOSE", file, ROUNDS, -1);
        }

        (void)u_puts(1, "D6FS-FRAG-PASS");
        (void)u_crlf(1);
        return 0;
}
