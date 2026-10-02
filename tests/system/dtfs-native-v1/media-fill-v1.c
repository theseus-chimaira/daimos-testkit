/* Test-only DTFS media mutator: reserve every currently free data block. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define DTFS_BLOCKS 578U
#define DTFS_LAST_BLOCK 577U
#define DTFS_DIR_BLOCK 100U
#define DTFS_OWNER_FREE 0U
#define DTFS_OWNER_RESERVED 036U
#define WORD36_MASK UINT64_C(0777777777777)

static uint32_t
le32(const unsigned char b[4])
{
    return (uint32_t)b[0] | ((uint32_t)b[1] << 8) |
           ((uint32_t)b[2] << 16) | ((uint32_t)b[3] << 24);
}

static void
put_le32(unsigned char b[4], uint32_t v)
{
    b[0] = (unsigned char)v;
    b[1] = (unsigned char)(v >> 8);
    b[2] = (unsigned char)(v >> 16);
    b[3] = (unsigned char)(v >> 24);
}

static int
read_word(FILE *fp, uint64_t *word)
{
    unsigned char raw[8];
    uint32_t hi, lo;

    if (fread(raw, 1, sizeof raw, fp) != sizeof raw)
        return -1;
    hi = le32(raw) & 0x3ffffU;
    lo = le32(raw + 4) & 0x3ffffU;
    *word = (((uint64_t)hi << 18) | lo) & WORD36_MASK;
    return 0;
}

static int
write_word(FILE *fp, uint64_t word)
{
    unsigned char raw[8];

    put_le32(raw, (uint32_t)((word >> 18) & 0x3ffffU));
    put_le32(raw + 4, (uint32_t)(word & 0x3ffffU));
    return fwrite(raw, 1, sizeof raw, fp) == sizeof raw ? 0 : -1;
}

static unsigned int
owner(const uint64_t dir[128], unsigned int block)
{
    unsigned int wi = block / 7U;
    unsigned int shift = 31U - (block % 7U) * 5U;
    return (unsigned int)((dir[wi] >> shift) & 037U);
}

static void
set_owner(uint64_t dir[128], unsigned int block, unsigned int value)
{
    unsigned int wi = block / 7U;
    unsigned int shift = 31U - (block % 7U) * 5U;
    uint64_t mask = UINT64_C(037) << shift;

    dir[wi] = (dir[wi] & ~mask) | ((uint64_t)(value & 037U) << shift);
}

int
main(int argc, char **argv)
{
    FILE *fp;
    uint64_t dir[128];
    unsigned int i;
    long offset;

    if (argc != 2) {
        fprintf(stderr, "usage: media-fill-v1 TAPE\n");
        return 2;
    }
    fp = fopen(argv[1], "r+b");
    if (fp == NULL) {
        perror(argv[1]);
        return 1;
    }
    offset = (long)DTFS_DIR_BLOCK * 256L * 4L;
    if (fseek(fp, offset, SEEK_SET) != 0) {
        fclose(fp);
        return 1;
    }
    for (i = 0U; i < 128U; ++i) {
        if (read_word(fp, &dir[i]) != 0) {
            fclose(fp);
            return 1;
        }
    }
    for (i = 1U; i <= DTFS_LAST_BLOCK; ++i) {
        if (i != DTFS_DIR_BLOCK && owner(dir, i) == DTFS_OWNER_FREE)
            set_owner(dir, i, DTFS_OWNER_RESERVED);
    }
    if (fseek(fp, offset, SEEK_SET) != 0) {
        fclose(fp);
        return 1;
    }
    for (i = 0U; i < 128U; ++i) {
        if (write_word(fp, dir[i]) != 0) {
            fclose(fp);
            return 1;
        }
    }
    if (fclose(fp) != 0)
        return 1;
    return 0;
}
