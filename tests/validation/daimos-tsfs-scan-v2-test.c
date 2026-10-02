#include <stdio.h>
#include <string.h>

#include "tsfs_scan.h"

#define MASK36 0777777777777UL
#define HALF18 0777777UL
#define TSFS_MAGIC 0646346630000UL
#define TSDIR_MAGIC 0646344516200UL
#define TSFS_VERSION (((kword_t)1U << 18) | 1U)
#define D_MAGIC 0U
#define D_VERSION 1U
#define D_ID_HI 3U
#define D_ID_LO 4U
#define D_GENERATION 5U
#define D_MEMBER 6U
#define D_BLOCKS 7U
#define D_TDIR 8U
#define D_TDIR_BLOCKS 9U
#define D_TDIR_CHECKSUM 10U
#define D_CHECKSUM 11U
#define TD_CHECKSUM 6U
#define TD_FIRST_ENTRY 7U
#define FILE_WORDS 8U
#define EXTENT_WORDS 4U

static kword_t media[8][8][TSFS_BLOCK_WORDS];
static unsigned int present[8];

static kword_t
rol36(kword_t v)
{
        v &= MASK36;
        return ((v << 1) | (v >> 35)) & MASK36;
}

static kword_t
checksum_block(const kword_t *p, unsigned int skip)
{
        kword_t sum;
        unsigned int i;

        sum = 0;
        for (i = 0U; i < TSFS_BLOCK_WORDS; ++i) {
                sum = rol36(sum);
                if (i != skip)
                        sum ^= p[i] & MASK36;
                sum = (sum + 1U) & MASK36;
        }
        return sum;
}

static kword_t
checksum_table(const kword_t *p)
{
        return checksum_block(p, TSFS_BLOCK_WORDS);
}

static void
make_descriptor(unsigned int unit, unsigned int members, unsigned int member,
    unsigned int tdir_member, kword_t tdir_sum)
{
        unsigned int replica;

        present[unit] = 1U;
        for (replica = 1U; replica <= 2U; ++replica) {
                kword_t *p;

                p = media[unit][replica];
                memset(p, 0, sizeof(media[unit][replica]));
                p[D_MAGIC] = TSFS_MAGIC;
                p[D_VERSION] = TSFS_VERSION;
                p[D_ID_HI] = 01234567UL;
                p[D_ID_LO] = 07654321UL;
                p[D_GENERATION] = 7U;
                p[D_MEMBER] = ((kword_t)members << 18) | member;
                p[D_BLOCKS] = TSFS_BLOCK_COUNT;
                p[D_TDIR] = ((kword_t)tdir_member << 18) | 3U;
                p[D_TDIR_BLOCKS] = 1U;
                p[D_TDIR_CHECKSUM] = tdir_sum;
                p[D_CHECKSUM] = checksum_block(p, D_CHECKSUM);
        }
}

static kword_t
make_metadata(unsigned int unit)
{
        kword_t *file;
        kword_t *extent;
        kword_t *td;
        kword_t file_sum;
        kword_t extent_sum;

        file = media[unit][4];
        memset(file, 0, sizeof(media[unit][4]));
        file[0] = 1U;
        file[7] = ((kword_t)1U << 18) | 1U;
        file[8] = 2U;
        file[8 + 5] = 01000U;
        file[8 + 6] = 2U;
        file_sum = checksum_table(file);

        extent = media[unit][5];
        memset(extent, 0, sizeof(media[unit][5]));
        extent[0] = 0U;
        extent[1] = 6U;
        extent[2] = 2U;
        extent[4] = 0400U;
        extent[5] = ((kword_t)1U << 18) | 6U;
        extent[6] = 2U;
        extent_sum = checksum_table(extent);

        td = media[unit][3];
        memset(td, 0, sizeof(media[unit][3]));
        td[0] = TSDIR_MAGIC;
        td[1] = TSFS_VERSION;
        td[3] = 2U;
        td[4] = 2U;
        td[TD_FIRST_ENTRY + 0U] = (kword_t)1U << 18;
        td[TD_FIRST_ENTRY + 1U] = ((kword_t)2U << 18) | 4U;
        td[TD_FIRST_ENTRY + 2U] = ((kword_t)1U << 18) | FILE_WORDS;
        td[TD_FIRST_ENTRY + 3U] = 2U;
        td[TD_FIRST_ENTRY + 4U] = file_sum;
        td[TD_FIRST_ENTRY + 5U] = (kword_t)2U << 18;
        td[TD_FIRST_ENTRY + 6U] = ((kword_t)2U << 18) | 5U;
        td[TD_FIRST_ENTRY + 7U] = ((kword_t)1U << 18) | EXTENT_WORDS;
        td[TD_FIRST_ENTRY + 8U] = 2U;
        td[TD_FIRST_ENTRY + 9U] = extent_sum;
        td[TD_CHECKSUM] = checksum_block(td, TD_CHECKSUM);
        return td[TD_CHECKSUM];
}

int
dsys_dtc_read_block(unsigned int unit, unsigned int block, kword_t *buf)
{
        if (unit >= 8U || !present[unit] || block < 1U || block > 7U)
                return -1;
        memcpy(buf, media[unit][block], sizeof(media[unit][block]));
        return 0;
}

int
main(void)
{
        struct tsfs_scan_result r;
        kword_t handoff[SYS_TSFS_MOUNT_WORDS];
        kword_t tdir_sum;
        kword_t hi;

        present[7] = 1U;
        tdir_sum = make_metadata(7U);
        make_descriptor(4U, 3U, 0U, 2U, tdir_sum);
        make_descriptor(1U, 3U, 1U, 2U, tdir_sum);
        make_descriptor(7U, 3U, 2U, 2U, tdir_sum);

        if (tsfs_scan(4U, &r) != 0 || r.members != 3U ||
            r.unit[0] != 4U || r.unit[1] != 1U || r.unit[2] != 7U ||
            r.tdir_member != 2U || r.tdir_block != 3U)
                return 1;
        if (tsfs_build_mount_handoff(&r, handoff) != 0)
                return 1;
        hi = (handoff[SYS_TSFS_FILE_LOC] >> 18) & HALF18;
        if ((unsigned int)(hi >> 15) != 7U ||
            (unsigned int)(hi & 077777U) != 2U ||
            (unsigned int)(handoff[SYS_TSFS_FILE_LOC] & HALF18) != 4U ||
            handoff[SYS_TSFS_FILE_SHAPE] != 0714U)
                return 1;
        hi = (handoff[SYS_TSFS_EXTENT_LOC] >> 18) & HALF18;
        if ((unsigned int)(hi >> 15) != 7U ||
            (unsigned int)(hi & 077777U) != 2U ||
            (unsigned int)(handoff[SYS_TSFS_EXTENT_LOC] & HALF18) != 5U)
                return 1;
        puts("daimos-tsfs-scan-v2: PASS (multi-extent cross-member handoff)");
        return 0;
}
