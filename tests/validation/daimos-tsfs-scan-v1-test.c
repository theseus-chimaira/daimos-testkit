#include <stdio.h>
#include <string.h>

#include "tsfs_scan.h"

#define MASK36 0777777777777UL
#define TSFS_MAGIC 0646346630000UL
#define TSFS_VERSION ((kword_t)1U << 18)
#define D_MAGIC 0U
#define D_VERSION 1U
#define D_FLAGS 2U
#define D_ID_HI 3U
#define D_ID_LO 4U
#define D_GENERATION 5U
#define D_MEMBER 6U
#define D_BLOCKS 7U
#define D_TDIR 8U
#define D_TDIR_BLOCKS 9U
#define D_TDIR_CHECKSUM 10U
#define D_CHECKSUM 11U

static kword_t media[8][3][TSFS_BLOCK_WORDS];
static unsigned int present[8];

static kword_t
rol36(kword_t v)
{
        v &= MASK36;
        return ((v << 1) | (v >> 35)) & MASK36;
}

static kword_t
checksum(const kword_t *p, unsigned int skip)
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

static void
make_descriptor(unsigned int unit, unsigned int members, unsigned int member,
    unsigned int tdir_member)
{
        unsigned int replica;

        present[unit] = 1U;
        for (replica = 1U; replica <= 2U; ++replica) {
                kword_t *p = media[unit][replica];

                memset(p, 0, sizeof(media[unit][replica]));
                p[D_MAGIC] = TSFS_MAGIC;
                p[D_VERSION] = TSFS_VERSION;
                p[D_FLAGS] = 0;
                p[D_ID_HI] = 01234567UL;
                p[D_ID_LO] = 07654321UL;
                p[D_GENERATION] = 7U;
                p[D_MEMBER] = ((kword_t)members << 18) | member;
                p[D_BLOCKS] = TSFS_BLOCK_COUNT;
                p[D_TDIR] = ((kword_t)tdir_member << 18) | 3U;
                p[D_TDIR_BLOCKS] = 1U;
                p[D_TDIR_CHECKSUM] = 012345670123UL;
                p[D_CHECKSUM] = checksum(p, D_CHECKSUM);
        }
}

int
dsys_dtc_read_block(unsigned int unit, unsigned int block, kword_t *buf)
{
        if (unit >= 8U || !present[unit] || block < 1U || block > 2U)
                return -1;
        memcpy(buf, media[unit][block], sizeof(media[unit][block]));
        return 0;
}

int
main(void)
{
        struct tsfs_scan_result r;
        kword_t handoff[SYS_TSFS_MOUNT_WORDS];

        /* Physical drive order deliberately differs from logical member order. */
        make_descriptor(4U, 3U, 0U, 2U);
        make_descriptor(1U, 3U, 1U, 2U);
        make_descriptor(7U, 3U, 2U, 2U);

        if (tsfs_scan(4U, &r) != 0 || r.members != 3U ||
            r.unit[0] != 4U || r.unit[1] != 1U || r.unit[2] != 7U ||
            r.tdir_member != 2U || r.tdir_block != 3U ||
            r.tdir_blocks != 1U)
                return 1;
        if (tsfs_build_mount_handoff(&r, handoff) != 0 ||
            handoff[SYS_TSFS_TDIR_MEMBER] != 2U ||
            handoff[SYS_TSFS_TDIR_BLOCK] != 3U ||
            handoff[SYS_TSFS_TDIR_BLOCKS] != 1U)
                return 1;
        puts("daimos-tsfs-scan-v1: PASS (shuffled members and nonzero TDIR member)");
        return 0;
}
