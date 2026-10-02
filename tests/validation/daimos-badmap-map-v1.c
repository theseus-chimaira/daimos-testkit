#include "kcore.h"
#include "badmap.h"

int __test_exit;

extern kword_t badmap_state[];
extern int badmap_map_test(kword_t logical, unsigned int *unitp, kword_t *blockp);
extern int badmap_read_block(kword_t logical, kword_t *buffer);
extern int badmap_write_block(kword_t logical, kword_t *buffer);
extern void badmap_patch_test_backends(void);
extern kword_t badmap_test_unit;
extern kword_t badmap_test_block;
extern kword_t badmap_test_buffer;
extern kword_t badmap_test_op;

static kword_t table[2];

static kword_t
locator(unsigned int member, kword_t block)
{
        return ((kword_t)member << BADMAP_LOC_MEMBER_SHIFT) |
            (block & BADMAP_LOC_BLOCK_MASK);
}

static void
setup(unsigned int unit, kword_t base, kword_t blocks,
    kword_t source, kword_t replacement)
{
        unsigned int i;

        for (i = 0U; i < 9U; ++i)
                badmap_state[i] = 0UL;
        table[0] = (source << 18U) | replacement;
        badmap_state[0] = 1UL;
        badmap_state[1] = (kword_t)(unsigned long)table;
        badmap_state[2] = 1UL;
        badmap_state[3] = (kword_t)unit;
        badmap_state[7] = base;
        badmap_state[8] = blocks;
}

static int
expect(kword_t logical, unsigned int unit, kword_t block)
{
        unsigned int got_unit;
        kword_t got_block;

        got_unit = 077U;
        got_block = 0777777UL;
        if (badmap_map_test(logical, &got_unit, &got_block) != 0)
                return 0;
        return got_unit == unit && got_block == block;
}

static int
check_dsk(void)
{
        setup(2U, 0100UL, 02000UL,
            locator(0U, 0123UL), locator(0U, 0760UL));
        if (!expect(022UL, 2U, 0122UL))
                return 1;
        if (!expect(023UL, 2U, 0760UL))
                return 2;
        if (!expect(024UL, 2U, 0124UL))
                return 3;
        return 0;
}

static int
check_drm(void)
{
        setup(5U, 01000UL, 0100000UL,
            locator(0U, 07777UL), locator(0U, 0170000UL));
        if (!expect(06776UL, 5U, 07776UL))
                return 1;
        if (!expect(06777UL, 5U, 0170000UL))
                return 2;
        if (!expect(07000UL, 5U, 010000UL))
                return 3;
        return 0;
}


static int
check_raw_tail(void)
{
        /* The exported filesystem span is 0200 blocks.  Logical 0203 is
         * therefore raw-tail block 3 after fs_mres adds blockset_direct_blocks.
         * BADMAP sees the unified logical namespace and remaps its physical
         * source exactly like an ordinary filesystem block. */
        setup(3U, 0100UL, 0210UL,
            locator(0U, 0303UL), locator(0U, 0760UL));
        if (!expect(0203UL, 3U, 0760UL))
                return 1;
        if (!expect(0204UL, 3U, 0304UL))
                return 2;
        return 0;
}

static int
check_io_wrapper(void)
{
        static kword_t buffer[4];

        setup(3U, 0100UL, 02000UL,
            locator(0U, 0123UL), locator(0U, 0760UL));
        badmap_patch_test_backends();
        badmap_test_op = 0UL;
        if (badmap_read_block(023UL, buffer) != 0 ||
            badmap_test_op != 1UL || badmap_test_unit != 3UL ||
            badmap_test_block != 0760UL ||
            badmap_test_buffer != (kword_t)(unsigned long)buffer)
                return 1;
        badmap_test_op = 0UL;
        if (badmap_write_block(024UL, buffer) != 0 ||
            badmap_test_op != 2UL || badmap_test_unit != 3UL ||
            badmap_test_block != 0124UL ||
            badmap_test_buffer != (kword_t)(unsigned long)buffer)
                return 2;
        return 0;
}

int
main(void)
{
        int rc;

        rc = check_dsk();
        if (rc != 0)
                return 10 + rc;
        rc = check_drm();
        if (rc != 0)
                return 20 + rc;
        rc = check_raw_tail();
        if (rc != 0)
                return 30 + rc;
        rc = check_io_wrapper();
        if (rc != 0)
                return 40 + rc;
        return 0;
}
