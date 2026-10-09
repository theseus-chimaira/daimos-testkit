/* Regression: one D6FS file must grow beyond seven 8-block reservations.
 * A mistaken reader.fcb_count versus reader.total_blocks comparison forces
 * every extension into a new FCB extent and fails despite plentiful space.
 * This test intentionally writes full 128-word buffers, like native KCPP. */
#include "u.h"

#define CHUNK_WORDS 128U
#define WRITE_CHUNKS 96U

static kword_t path[U_PATH_WORDS];
static kword_t words[CHUNK_WORDS];

static int
fail(const char *stage, kword_t value)
{
        (void)u_puts(2, "D6FS-EXTENT-GROWTH-FAIL ");
        (void)u_puts(2, stage);
        (void)u_puts(2, " VALUE=");
        (void)u_put_octal(2, value, 12U);
        (void)u_crlf(2);
        return 1;
}

static int
verify_word(int fd, unsigned int offset)
{
        kword_t received;
        kword_t expected;

        expected = 012340000000UL | (kword_t)offset;
        if (dsys_seek(fd, (kword_t)offset, SYS_SEEK_SET) !=
            (kword_t)offset)
                return fail("SEEK", (kword_t)offset);
        received = 0UL;
        if (dsys_read_words(fd, &received, 1U) != 1)
                return fail("READ", (kword_t)offset);
        if (received != expected)
                return fail("DATA", received);
        return 0;
}

int
main(void)
{
        struct vfs_stat st;
        unsigned int chunk;
        unsigned int i;
        int fd;
        int count;

        if (u_s6_pack(path, U_PATH_WORDS, "/CONFIG/D6EXTEND.DATA") != 0)
                return fail("PACK", 0UL);
        fd = dsys_open(path, SYS_O_RDWR | SYS_O_CREAT | SYS_O_TRUNC);
        if (fd < 0)
                return fail("OPEN", (kword_t)fd);

        for (chunk = 0U; chunk < WRITE_CHUNKS; ++chunk) {
                for (i = 0U; i < CHUNK_WORDS; ++i)
                        words[i] = 012340000000UL |
                            (kword_t)(chunk * CHUNK_WORDS + i);
                count = dsys_write_words(fd, words, CHUNK_WORDS);
                if (count != (int)CHUNK_WORDS)
                        return fail("WRITE-CHUNK", (kword_t)chunk);
        }
        if (dsys_close(fd) != 0)
                return fail("CLOSE", 0UL);
        if (dsys_stat(path, &st) != 0 ||
            st.size_words != (kword_t)(WRITE_CHUNKS * CHUNK_WORDS))
                return fail("STAT", st.size_words);

        fd = dsys_open(path, SYS_O_RDONLY);
        if (fd < 0)
                return fail("REOPEN", (kword_t)fd);
        if (verify_word(fd, 0U) != 0 ||
            verify_word(fd, 7167U) != 0 ||
            verify_word(fd, 7168U) != 0 ||
            verify_word(fd, 8191U) != 0 ||
            verify_word(fd, WRITE_CHUNKS * CHUNK_WORDS - 1U) != 0)
                return 1;
        if (dsys_close(fd) != 0)
                return fail("FINAL-CLOSE", 0UL);
        (void)u_puts(1, "D6FS-EXTENT-GROWTH-PASS\r\n");
        return 0;
}
