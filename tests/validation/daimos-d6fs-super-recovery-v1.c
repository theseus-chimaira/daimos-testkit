#include <stdio.h>
#include <string.h>

#include "d6fs.h"

static void
make_super(kword_t sb[D6FS_SUPER_WORDS], kword_t sequence,
    unsigned int state)
{
        memset(sb, 0, sizeof(kword_t) * D6FS_SUPER_WORDS);
        sb[D6FS_SB_MAGIC_VERSION] =
            (D6FS_MAGIC & ~077UL) | D6FS_FORMAT_VERSION;
        sb[D6FS_SB_SEQUENCE] = sequence;
        sb[D6FS_SB_STATE] = state;
        sb[D6FS_SB_FS_UUID0] = 012345670123UL;
        sb[D6FS_SB_FS_UUID1] = 076543210765UL;
        sb[D6FS_SB_TOTAL_BLOCKS] = 01000UL;
        sb[D6FS_SB_ROOT_FCB] = 0UL;
        sb[D6FS_SB_FCB_START] = 2UL;
        sb[D6FS_SB_FCB_COUNT] = 8UL;
        sb[D6FS_SB_FREEMAP_START] = 3UL;
        sb[D6FS_SB_FREEMAP_BLOCKS] = 1UL;
        sb[D6FS_SB_SUMMARY_START] = 4UL;
        sb[D6FS_SB_SUMMARY_BLOCKS] = 1UL;
}

int
main(void)
{
        kword_t a[D6FS_SUPER_WORDS];
        kword_t b[D6FS_SUPER_WORDS];
        struct d6fs_super_info info;
        unsigned int copy;

        make_super(a, 4UL, D6FS_STATE_CLEAN);
        make_super(b, 5UL, D6FS_STATE_CLEAN);
        if (d6fs_super_select(a, b, 01000UL, &info, &copy) != 0 ||
            copy != 1U || info.sequence != 5UL)
                return 1;

        /* Never fall back to the older CLEAN generation once a newer DIRTY
         * generation exists: metadata may already have been changed. */
        make_super(a, 4UL, D6FS_STATE_CLEAN);
        make_super(b, 5UL, D6FS_STATE_DIRTY);
        if (d6fs_super_select(a, b, 01000UL, &info, &copy) == 0)
                return 2;

        /* A torn/invalid alternate publication is harmless when the remaining
         * selected generation is structurally valid and CLEAN. */
        make_super(a, 4UL, D6FS_STATE_CLEAN);
        make_super(b, 5UL, D6FS_STATE_CLEAN);
        b[D6FS_SB_MAGIC_VERSION] = 0UL;
        if (d6fs_super_select(a, b, 01000UL, &info, &copy) != 0 ||
            copy != 0U || info.sequence != 4UL)
                return 3;

        make_super(a, 7UL, D6FS_STATE_CLEAN);
        make_super(b, 7UL, D6FS_STATE_DIRTY);
        if (d6fs_super_select(a, b, 01000UL, &info, &copy) == 0)
                return 4;

        /* Sequence ordering is modulo 36 bits.  Zero immediately follows the
         * maximum 36-bit sequence and must therefore be selected as newer. */
        make_super(a, 0777777777777UL, D6FS_STATE_CLEAN);
        make_super(b, 0UL, D6FS_STATE_CLEAN);
        if (d6fs_super_select(a, b, 01000UL, &info, &copy) != 0 ||
            copy != 1U || info.sequence != 0UL)
                return 5;

        /* Exactly half the sequence space apart has no unambiguous ordering. */
        make_super(a, 0UL, D6FS_STATE_CLEAN);
        make_super(b, 0400000000000UL, D6FS_STATE_CLEAN);
        if (d6fs_super_select(a, b, 01000UL, &info, &copy) == 0)
                return 6;

        return 0;
}
