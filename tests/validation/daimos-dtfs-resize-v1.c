typedef unsigned long kword_t;
typedef unsigned long vnode_t;

#define BLOCK_WORDS 0200U
#define DATA_WORDS 0177U
#define P_NATIVE 0U
#define P_TENEX 010U
#define P_ITS 020U

kword_t fs_block_workspace[BLOCK_WORDS];
int __test_exit;

static unsigned int personality;
static unsigned int blocks;
static unsigned int first_block;
static kword_t h5;
static kword_t h6;
static unsigned int owner_calls;
static unsigned int owner_last;
static unsigned int write_calls;
static unsigned int commit_calls;
static unsigned int last_words_value;
static int its_calls;

int dtfs_resize(vnode_t, unsigned int);

static kword_t header(unsigned int next, unsigned int first, unsigned int n)
{
        return ((kword_t)next << 18) | ((kword_t)first << 8) | n;
}

int dtfs_is_file(vnode_t node) { (void)node; return 1; }
int dtfs_load(vnode_t node) { (void)node; return 0; }
unsigned int dtfs_personality(vnode_t node) { (void)node; return personality; }
unsigned int dtfs_unit(vnode_t node) { (void)node; return 0U; }
unsigned int dtfs_block_info(vnode_t node, unsigned int slot, unsigned int *firstp)
{
        (void)node; (void)slot;
        if (firstp != 0) *firstp = first_block;
        return blocks;
}
int dtfs_its_resize(vnode_t node, unsigned int words, int grow_only)
{
        (void)node; (void)words;
        if (grow_only != 0) return -7;
        ++its_calls;
        return 23;
}
int dtfs_dtc_read(unsigned int unit, unsigned int block, kword_t *buf)
{
        unsigned int i;
        (void)unit;
        for (i = 0; i < BLOCK_WORDS; ++i) buf[i] = 0;
        if (block == 5U) buf[0] = h5;
        else if (block == 6U) buf[0] = h6;
        else return -1;
        return 0;
}
int dtfs_dtc_write(unsigned int unit, unsigned int block, kword_t *buf)
{
        (void)unit;
        ++write_calls;
        if (block == 5U) h5 = buf[0];
        else if (block == 6U) h6 = buf[0];
        else return -1;
        return 0;
}
int dtfs_find_free_block(unsigned int start, int tenex, unsigned int *blockp)
{
        (void)start; (void)tenex;
        *blockp = 6U;
        return 0;
}
void fs_zero_block_workspace(void)
{
        unsigned int i;
        for (i = 0; i < BLOCK_WORDS; ++i) fs_block_workspace[i] = 0;
}
void dtfs_set_owner(unsigned int base, unsigned int index, unsigned int owner)
{
        (void)base; (void)index;
        ++owner_calls;
        owner_last = owner;
}
void dtfs_set_last_words(unsigned int slot, unsigned int words)
{
        (void)slot;
        last_words_value = words;
}
int dtfs_commit(vnode_t node) { (void)node; ++commit_calls; return 0; }

static void reset(unsigned int p, unsigned int n)
{
        personality = p;
        blocks = n;
        first_block = n == 0U ? 0U : 5U;
        h5 = header(n > 1U ? 6U : 0U, 5U, DATA_WORDS);
        h6 = header(0U, 5U, 3U);
        owner_calls = 0U;
        owner_last = 0777U;
        write_calls = 0U;
        commit_calls = 0U;
        last_words_value = 0777U;
        its_calls = 0;
}

static int test_its(void)
{
        reset(P_ITS, 0U);
        if (dtfs_resize(2UL, 10U) != 23 || its_calls != 1 || commit_calls != 0U)
                return 1;
        return 0;
}

static int test_equal(unsigned int p)
{
        reset(p, 1U);
        if (dtfs_resize(2UL, 10U) != 0 || commit_calls != 1U ||
            write_calls != 1U || owner_calls != 0U)
                return 2;
        return 0;
}

static int test_boundaries(unsigned int p)
{
        reset(p, 1U);
        if (dtfs_resize(2UL, 1U) != 0)
                return 5;
        if (p == P_NATIVE) {
                if (last_words_value != 1U) return 6;
        } else if ((unsigned int)(h5 & 0177UL) != 1U) {
                return 6;
        }
        reset(p, 1U);
        if (dtfs_resize(2UL, DATA_WORDS) != 0)
                return 7;
        if (p == P_NATIVE) {
                if (last_words_value != DATA_WORDS) return 8;
        } else if ((unsigned int)(h5 & 0177UL) != DATA_WORDS) {
                return 8;
        }
        reset(p, 2U);
        if (dtfs_resize(2UL, DATA_WORDS + 1U) != 0)
                return 9;
        if (p == P_NATIVE) {
                if (last_words_value != 1U) return 10;
        } else if ((unsigned int)(h6 & 0177UL) != 1U) {
                return 10;
        }
        return 0;
}

static int test_grow(unsigned int p)
{
        reset(p, 1U);
        if (dtfs_resize(2UL, DATA_WORDS + 3U) != 0 || commit_calls != 1U ||
            write_calls < 2U || owner_calls != 1U || owner_last != 3U)
                return 3;
        return 0;
}

static int test_shrink(unsigned int p)
{
        reset(p, 2U);
        if (dtfs_resize(2UL, 9U) != 0 || commit_calls != 1U ||
            owner_calls != 1U || owner_last != 0U)
                return 4;
        return 0;
}

int main(void)
{
        int r;
        r = test_its(); if (r) return r;
        r = test_equal(P_NATIVE); if (r) return r + 10;
        r = test_equal(P_TENEX); if (r) return r + 20;
        r = test_boundaries(P_NATIVE); if (r) return r + 25;
        r = test_boundaries(P_TENEX); if (r) return r + 27;
        r = test_grow(P_NATIVE); if (r) return r + 30;
        r = test_grow(P_TENEX); if (r) return r + 40;
        r = test_shrink(P_NATIVE); if (r) return r + 50;
        r = test_shrink(P_TENEX); if (r) return r + 60;
        return 0;
}
