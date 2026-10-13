/* Verify that an actual staged TSFS 1.3 extent carries inline flag 2. */
#include <stdio.h>
#include <stdint.h>
#include "tsfs-format-v069.h"
int main(int argc, char **argv)
{
    uint64_t descriptor[TSFS_BLOCK_WORDS], directory[TSFS_BLOCK_WORDS];
    uint64_t table[TSFS_BLOCK_WORDS];
    size_t i;
    unsigned int member, block, records, found = 0U;
    if (argc != 2 || tsfs_read_image_block(argv[1], 1U, descriptor) != 0)
        return 1;
    if ((descriptor[TSFS_DESC_VERSION_WORD] & TSFS_HALF_MASK) != 3U)
        return 2;
    if (tsfs_read_image_block(argv[1],
        (unsigned int)descriptor[TSFS_DESC_TDIR_WORD], directory) != 0)
        return 3;
    for (i = TSFS_TDIR_USED_WORDS; i + TSFS_TDIRE_WORDS <= TSFS_BLOCK_WORDS;
        i += TSFS_TDIRE_WORDS) {
        uint64_t shape;
        if ((directory[i + TSFS_TDIRE_ID_FLAGS] >> 18U) != TSFS_TABLE_EXTENT)
            continue;
        member = (unsigned int)(directory[i + TSFS_TDIRE_MEMBER_BLOCK] >> 18U);
        block = (unsigned int)(directory[i + TSFS_TDIRE_MEMBER_BLOCK] & TSFS_HALF_MASK);
        shape = directory[i + TSFS_TDIRE_BLOCKS_RECWORDS];
        records = (unsigned int)directory[i + TSFS_TDIRE_RECORD_COUNT];
        if (member != 0U || (shape >> 18U) == 0U || records == 0U ||
            tsfs_read_image_block(argv[1], block, table) != 0)
            return 4;
        for (unsigned int j = 0; j < records && j < TSFS_BLOCK_WORDS / TSFS_EXTENT_WORDS; ++j) {
            uint64_t flag = table[j * TSFS_EXTENT_WORDS + TSFS_EXTENT_SHAPE] >> 18U;
            if (flag == TSFS_EXTENT_FLAG_D6INLINE_V069)
                ++found;
            else if (flag != TSFS_EXTENT_FLAG_STORED)
                return 5;
        }
        break;
    }
    if (found == 0U) {
        fputs("no actual inline compressed extent\n", stderr);
        return 6;
    }
    printf("PASS v074 found %u inline compressed extent(s)\n", found);
    return 0;
}
