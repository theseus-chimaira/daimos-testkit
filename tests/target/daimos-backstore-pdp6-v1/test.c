#include "bstore.h"

static kword_t bitmap[2];
kword_t daimos_backstore_pdp6_result;

static int
check_bits(kword_t word, kword_t mask, kword_t expected)
{
        return (word & mask) == expected;
}

int
daimos_backstore_pdp6_test(void)
{
        kword_t first;

        if (backstore_bitmap_words(0UL) != 0U ||
            backstore_bitmap_words(1UL) != 1U ||
            backstore_bitmap_words(36UL) != 1U ||
            backstore_bitmap_words(37UL) != 2U)
                return 1;

        bitmap[0] = 0UL;
        bitmap[1] = 0UL;
        backstore_init(bitmap, 72UL);
        if (backstore_bitmap != bitmap || backstore_blocks != 72UL ||
            backstore_blocks_used != 0UL || backstore_enabled != 0U)
                return 2;
        backstore_enabled = 1U;

        if (backstore_alloc(63UL, 10UL, &first) == 0)
                return 3;
        if (backstore_alloc(3UL, 10UL, &first) != 0 || first != 0UL ||
            backstore_blocks_used != 3UL ||
            !check_bits(bitmap[0], 07UL, 07UL))
                return 4;
        if (backstore_alloc(2UL, 10UL, &first) != 0 || first != 3UL ||
            backstore_blocks_used != 5UL ||
            !check_bits(bitmap[0], 037UL, 037UL))
                return 5;

        backstore_free(0UL, 3UL);
        if (backstore_blocks_used != 2UL ||
            !check_bits(bitmap[0], 037UL, 030UL))
                return 6;
        if (backstore_alloc(2UL, 0UL, &first) != 0 || first != 0UL)
                return 7;
        backstore_free(0UL, 2UL);
        backstore_free(3UL, 2UL);
        if (backstore_blocks_used != 0UL || bitmap[0] != 0UL)
                return 8;

        if (backstore_alloc(35UL, 0UL, &first) != 0 || first != 0UL)
                return 9;
        if (backstore_alloc(2UL, 0UL, &first) != 0 || first != 35UL)
                return 10;
        if (bitmap[0] != 0777777777777UL ||
            !check_bits(bitmap[1], 1UL, 1UL))
                return 11;
        backstore_free(0UL, 37UL);
        if (backstore_blocks_used != 0UL || bitmap[0] != 0UL ||
            bitmap[1] != 0UL)
                return 12;

        backstore_free(72UL, 1UL);
        if (backstore_blocks_used != 0UL)
                return 13;
        return 0;
}
