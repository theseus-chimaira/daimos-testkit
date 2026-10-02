#include "d6lz.h"

/* Historical memory-decoder ABI supplied by the test harness wrapper. */
int d6lz36_decode(kword_t *dst, unsigned int dst_words,
    const kword_t *src, unsigned int src_words);

#define MATCH_TOKEN(distance, length) \
        ((kword_t)(((distance) - 1U) | (((length) - 3U) << 7)))

kword_t daimos_d6lz_pdp6_result;

static kword_t out[300];
static kword_t stream[140];
static const kword_t *vfs_source;
static unsigned int vfs_source_words;

int
vfs_read_words(kword_t node, kword_t off, kword_t *buf, unsigned int words)
{
        unsigned int avail;
        unsigned int i;

        if (node != 1UL || off >= (kword_t)vfs_source_words)
                return 0;
        avail = vfs_source_words - (unsigned int)off;
        if (words > avail)
                words = avail;
        for (i = 0U; i < words; ++i)
                buf[i] = vfs_source[(unsigned int)off + i];
        return (int)words;
}

static kword_t
pack_vfs_destination(kword_t *dst, unsigned int words)
{
        return ((kword_t)words << 18U) | ((kword_t)dst & 0777777UL);
}

static int
test_vfs_windows(void)
{
        unsigned int i;
        int rc;

        /* 42 compressed words force refills at 8-word boundaries, including
         * a control-word transition near the end of the stream. */
        stream[0] = 0UL;
        for (i = 0U; i < 36U; ++i)
                stream[1U + i] = (kword_t)(01000U + i);
        stream[37] = 0UL;
        for (i = 0U; i < 4U; ++i)
                stream[38U + i] = (kword_t)(02000U + i);
        vfs_source = stream;
        vfs_source_words = 42U;
        rc = d6lz36_decode_vfs(1UL, 0UL, 42U,
            pack_vfs_destination(out, 40U));
        if (rc != 0)
                return 1;
        for (i = 0U; i < 36U; ++i)
                if (out[i] != (kword_t)(01000U + i))
                        return 2;
        for (i = 0U; i < 4U; ++i)
                if (out[36U + i] != (kword_t)(02000U + i))
                        return 3;

        /* Exact compressed payload consumption is part of the VFS ABI. */
        stream[42] = 012345UL;
        vfs_source_words = 43U;
        if (d6lz36_decode_vfs(1UL, 0UL, 43U,
            pack_vfs_destination(out, 40U)) != -1)
                return 4;
        return 0;
}

static kword_t
overlap_word(unsigned int i)
{
        return (kword_t)(01000U + ((i * 037U + 7U) & 0777U));
}

static unsigned int
make_overlap_stream(unsigned int distance, unsigned int length)
{
        unsigned int control_index;
        unsigned int slot;
        unsigned int sp;
        unsigned int token_index;
        kword_t control;

        sp = 0U;
        token_index = 0U;
        while (token_index <= distance) {
                control_index = sp++;
                control = 0;
                slot = 0U;
                while (slot < 36U && token_index <= distance) {
                        if (token_index < distance) {
                                stream[sp++] = overlap_word(token_index);
                        } else {
                                control |= ((kword_t)1UL << (35U - slot));
                                stream[sp++] = MATCH_TOKEN(distance, length);
                        }
                        ++token_index;
                        ++slot;
                }
                stream[control_index] = control;
        }
        return sp;
}

static int
test_overlap_matrix(void)
{
        unsigned int distance;
        unsigned int i;
        unsigned int length;
        unsigned int src_words;

        for (distance = 1U; distance <= 128U; ++distance) {
                for (length = 3U; length <= 130U; ++length) {
                        src_words = make_overlap_stream(distance, length);
                        if (d6lz36_decode(out, distance + length, stream,
                            src_words) != 0)
                                return 1;
                        for (i = 0U; i < distance; ++i)
                                if (out[i] != overlap_word(i))
                                        return 2;
                        for (i = 0U; i < length; ++i)
                                if (out[distance + i] != out[i % distance])
                                        return 3;
                }
        }
        return 0;
}

int
daimos_d6lz_pdp6_test(void)
{
        unsigned int i;
        int rc;

        rc = d6lz36_decode(out, 0U, 0, 0U);
        if (rc != 0)
                return 1;

        stream[0] = 0UL;
        stream[1] = 0123456701234UL;
        stream[2] = 0765432107654UL;
        stream[3] = 1UL;
        stream[4] = 0777777777777UL;
        rc = d6lz36_decode(out, 4U, stream, 5U);
        if (rc != 0 || out[0] != stream[1] ||
            out[1] != stream[2] || out[2] != stream[3] ||
            out[3] != stream[4])
                return 2;

        stream[0] = 0040000000000UL; /* control bit 32: fourth token match */
        stream[1] = 0101UL;
        stream[2] = 0102UL;
        stream[3] = 0103UL;
        stream[4] = MATCH_TOKEN(3U, 9U);
        rc = d6lz36_decode(out, 12U, stream, 5U);
        if (rc != 0)
                return 3;
        for (i = 0U; i < 12U; ++i)
                if (out[i] != (kword_t)(0101U + (i % 3U)))
                        return 4;

        stream[0] = 0200000000000UL; /* bit 34: second token match */
        stream[1] = 0777UL;
        stream[2] = MATCH_TOKEN(1U, 129U);
        rc = d6lz36_decode(out, 130U, stream, 3U);
        if (rc != 0)
                return 5;
        for (i = 0U; i < 130U; ++i)
                if (out[i] != 0777UL)
                        return 6;

        stream[0] = 0400000000000UL;
        stream[1] = MATCH_TOKEN(1U, 3U);
        if (d6lz36_decode(out, 3U, stream, 2U) != -1)
                return 7;

        stream[0] = 0200000000000UL;
        stream[1] = 0123UL;
        stream[2] = 040000UL | MATCH_TOKEN(1U, 3U);
        if (d6lz36_decode(out, 4U, stream, 3U) != -1)
                return 8;

        stream[0] = 0200000000000UL;
        stream[1] = 0123UL;
        stream[2] = MATCH_TOKEN(1U, 4U);
        if (d6lz36_decode(out, 3U, stream, 3U) != -1)
                return 9;

        if (d6lz36_decode(0, 1U, stream, 2U) != -1 ||
            d6lz36_decode(out, 1U, 0, 1U) != -1)
                return 10;

        stream[0] = 0UL;
        for (i = 0U; i < 36U; ++i)
                stream[i + 1U] = (kword_t)(01000U + i);
        stream[37] = 0UL;
        for (i = 0U; i < 4U; ++i)
                stream[38U + i] = (kword_t)(02000U + i);
        rc = d6lz36_decode(out, 40U, stream, 42U);
        if (rc != 0)
                return 11;
        for (i = 0U; i < 36U; ++i)
                if (out[i] != (kword_t)(01000U + i))
                        return 12;
        for (i = 0U; i < 4U; ++i)
                if (out[36U + i] != (kword_t)(02000U + i))
                        return 13;

        /* A match must leave the destination cursor on the following word. */
        stream[0] = 0200000000000UL; /* second token is a match */
        stream[1] = 0777UL;
        stream[2] = MATCH_TOKEN(1U, 3U);
        stream[3] = 01234UL;
        rc = d6lz36_decode(out, 5U, stream, 4U);
        if (rc != 0 || out[0] != 0777UL || out[1] != 0777UL ||
            out[2] != 0777UL || out[3] != 0777UL || out[4] != 01234UL)
                return 14;

        rc = test_vfs_windows();
        if (rc != 0)
                return 20 + rc;
        return 0;
}
