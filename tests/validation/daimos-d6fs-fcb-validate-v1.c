#include "d6fs.h"

int __test_exit;

static void
clear_fcb(kword_t fcb[D6FS_FCB_WORDS])
{
        unsigned int i;

        for (i = 0U; i < D6FS_FCB_WORDS; ++i)
                fcb[i] = 0UL;
}

static void
make_regular(kword_t fcb[D6FS_FCB_WORDS], unsigned int tail,
    unsigned int extents, kword_t size, unsigned int parent)
{
        clear_fcb(fcb);
        fcb[D6FS_FCB_META] = ((kword_t)D6FS_TYPE_REG << 33) |
            ((kword_t)tail << 8) | ((kword_t)extents << 4);
        fcb[D6FS_FCB_SIZE] = size;
        fcb[D6FS_FCB_PARENT] = (kword_t)parent << 18;
}

int
main(void)
{
        kword_t fcb[D6FS_FCB_WORDS];
        struct d6fs_fcb_info info;

        clear_fcb(fcb);
        if (!d6fs_fcb_decode_valid(fcb, 100UL, 10U, &info) ||
            info.type != D6FS_TYPE_FREE || info.extent_count != 0U ||
            info.size_words != 0UL)
                return 1;

        fcb[D6FS_FCB_SIZE] = 1UL;
        if (d6fs_fcb_decode_valid(fcb, 100UL, 10U, &info))
                return 2;

        make_regular(fcb, 0U, 0U, 0UL, 1U);
        if (!d6fs_fcb_decode_valid(fcb, 100UL, 10U, &info) ||
            info.type != D6FS_TYPE_REG || info.parent_fcb != 1U)
                return 3;

        fcb[D6FS_FCB_META] |= (kword_t)5U << 8;
        if (d6fs_fcb_decode_valid(fcb, 100UL, 10U, &info))
                return 4;

        clear_fcb(fcb);
        fcb[D6FS_FCB_META] = ((kword_t)D6FS_TYPE_SYMLINK << 33) |
            ((kword_t)6U << 8);
        fcb[D6FS_FCB_PARENT] = 1UL << 18;
        if (!d6fs_fcb_decode_valid(fcb, 100UL, 10U, &info))
                return 5;
        fcb[D6FS_FCB_META] += 1UL << 8;
        if (d6fs_fcb_decode_valid(fcb, 100UL, 10U, &info))
                return 6;

        make_regular(fcb, 0U, 1U, 256UL, 1U);
        fcb[D6FS_FCB_EXTENT0] = (10UL << 12) | 1UL;
        if (!d6fs_fcb_decode_valid(fcb, 100UL, 10U, &info) ||
            info.extent_count != 1U || info.size_words != 256UL)
                return 7;
        fcb[D6FS_FCB_SIZE] = 257UL;
        if (d6fs_fcb_decode_valid(fcb, 100UL, 10U, &info))
                return 8;

        make_regular(fcb, 0U, 1U, 1UL, 1U);
        fcb[D6FS_FCB_EXTENT0] = (99UL << 12) | 1UL;
        if (d6fs_fcb_decode_valid(fcb, 100UL, 10U, &info))
                return 9;

        make_regular(fcb, 0U, 1U, 1UL, 1U);
        fcb[D6FS_FCB_EXTENT0] = 10UL << 12;
        fcb[D6FS_FCB_EXTENT0 + 1U] = 1UL;
        if (d6fs_fcb_decode_valid(fcb, 100UL, 10U, &info))
                return 10;

        make_regular(fcb, 0U, 0U, 0UL, 1U);
        fcb[D6FS_FCB_RESERVED0] = 1UL;
        if (d6fs_fcb_decode_valid(fcb, 100UL, 10U, &info))
                return 11;

        make_regular(fcb, 0U, 0U, 0UL, 10U);
        if (d6fs_fcb_decode_valid(fcb, 100UL, 10U, &info))
                return 12;

        return 0;
}
