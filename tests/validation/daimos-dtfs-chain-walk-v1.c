typedef unsigned long kword_t;

#define BLOCK_WORDS 0200U
#define DATA_WORDS 0177U
#define ITS_BASE 056U
#define ITS_END 037U

kword_t fs_block_workspace[BLOCK_WORDS];
static kword_t b1[BLOCK_WORDS];
static kword_t b2[BLOCK_WORDS];
static kword_t b5[BLOCK_WORDS];
static kword_t b6[BLOCK_WORDS];
static int writes;
static unsigned int owner_shift;
int __test_exit;
unsigned int dtfs_media[4];

int dtfs_chain_walk(unsigned int, unsigned int, unsigned int, kword_t *,
    unsigned int, unsigned int, int);
unsigned int dtfs_block_info(kword_t, unsigned int, unsigned int *);

static void copy(kword_t *d, const kword_t *s)
{
        unsigned int i;
        for (i = 0; i < BLOCK_WORDS; ++i)
                d[i] = s[i];
}

unsigned int dtfs_owner(unsigned int base, unsigned int index)
{
        if (base == ITS_BASE) {
                if (index == 0U || index == 1U)
                        return 2U;
                if (index == 2U)
                        return ITS_END;
                return 0U;
        }
        if (index == 5U - owner_shift || index == 6U - owner_shift)
                return 3U;
        return 0U;
}

int dtfs_dtc_read(unsigned int unit, unsigned int block, kword_t *buf)
{
        (void)unit;
        if (block == 1U) copy(buf, b1);
        else if (block == 2U) copy(buf, b2);
        else if (block == 5U) copy(buf, b5);
        else if (block == 6U) copy(buf, b6);
        else return -1;
        return 0;
}

int dtfs_dtc_write(unsigned int unit, unsigned int block, kword_t *buf)
{
        (void)unit;
        if (block == 1U) copy(b1, buf);
        else if (block == 2U) copy(b2, buf);
        else if (block == 5U) copy(b5, buf);
        else if (block == 6U) copy(b6, buf);
        else return -1;
        ++writes;
        return 0;
}

void fs_copy_words(const kword_t *src, kword_t *dst, unsigned int n)
{
        unsigned int i;
        for (i = 0; i < n; ++i)
                dst[i] = src[i];
}

static void init_native(void)
{
        unsigned int i;
        for (i = 0; i < BLOCK_WORDS; ++i) { b5[i] = 0; b6[i] = 0; }
        b5[0] = ((kword_t)6U << 18) | ((kword_t)5U << 8) | DATA_WORDS;
        b6[0] = ((kword_t)5U << 8) | 3U;
        for (i = 1; i < BLOCK_WORDS; ++i) b5[i] = 01000U + i;
        b6[1] = 02001U; b6[2] = 02002U; b6[3] = 02003U;
}

static int test_native(void)
{
        kword_t out[8];
        int n;
        init_native();
        owner_shift = 0U;
        n = dtfs_chain_walk(0U, 2U, 0U, (kword_t *)0, 0U, 0U, 0);
        if (n != 130) return 1;
        n = dtfs_chain_walk(0U, 2U, 126U, out, 4U, 0U, 0);
        if (n != 4 || out[0] != b5[127] || out[1] != b6[1] ||
            out[2] != b6[2] || out[3] != b6[3]) return 2;
        return 0;
}

static int test_tenex(void)
{
        kword_t out[4];
        int n;
        init_native();
        owner_shift = 1U;
        n = dtfs_chain_walk(0U, 2U, 126U, out, 4U, 1U, 0);
        if (n != 4 || out[0] != b5[127] || out[1] != b6[1]) return 3;
        return 0;
}

static int test_its(void)
{
        kword_t out[16];
        kword_t in[4];
        unsigned int i;
        int n;
        for (i = 0; i < BLOCK_WORDS; ++i) { b1[i] = 03000U+i; b2[i] = 04000U+i; }
        n = dtfs_chain_walk(0U, 1U, 120U, out, 16U, ITS_BASE, 0);
        if (n != 16) return 4;
        for (i = 0; i < 8U; ++i) if (out[i] != b1[120U+i]) return 5;
        for (i = 0; i < 8U; ++i) if (out[8U+i] != b2[i]) return 6;
        for (i = 0; i < 4U; ++i) in[i] = 05000U+i;
        writes = 0;
        n = dtfs_chain_walk(0U, 1U, 127U, in, 4U, ITS_BASE, 1);
        if (n != 4 || writes != 2 || b1[127] != in[0] ||
            b2[0] != in[1] || b2[2] != in[3]) return 7;
        return 0;
}

static int test_block_info(void)
{
        kword_t node;
        unsigned int first;
        unsigned int n;
        node = (kword_t)0102U << 18;
        init_native();
        owner_shift = 0U;
        dtfs_media[0] = 0U;
        first = 0777U;
        n = dtfs_block_info(node, 2U, &first);
        if (n != 2U || first != 5U) return 8;
        owner_shift = 1U;
        dtfs_media[0] = 010U;
        first = 0777U;
        n = dtfs_block_info(node, 2U, &first);
        if (n != 2U || first != 5U) return 9;
        dtfs_media[0] = 020U;
        first = 0777U;
        n = dtfs_block_info(node, 1U, &first);
        if (n != 2U || first != 0U) return 10;
        return 0;
}

static int test_corrupt(void)
{
        kword_t out[1];
        int n;
        init_native();
        owner_shift = 0U;
        b5[0] = ((kword_t)6U << 18) | ((kword_t)5U << 8) | 0200U;
        n = dtfs_chain_walk(0U, 2U, 0U, out, 1U, 0U, 0);
        if (n != -1) return 11;
        init_native();
        b5[0] = ((kword_t)7U << 18) | ((kword_t)5U << 8) | DATA_WORDS;
        n = dtfs_chain_walk(0U, 2U, 0U, out, 1U, 0U, 0);
        if (n != 1) return 12;
        n = dtfs_chain_walk(0U, 2U, DATA_WORDS, out, 1U, 0U, 0);
        if (n != -1) return 13;
        return 0;
}

int main(void)
{
        int r;
        r = test_native(); if (r) return r;
        r = test_tenex(); if (r) return r;
        r = test_its(); if (r) return r;
        r = test_block_info(); if (r) return r;
        r = test_corrupt(); if (r) return r;
        return 0;
}
