#include <stdio.h>
#include <string.h>

#include "kinit.h"
#include "module.h"
#include "fs_mres.h"
#include "tsfs.h"

#define MASK36 0777777777777UL
#define TSFS_MAGIC 0646346630000UL
#define TSDIR_MAGIC 0646344516200UL
#define TSFS_VERSION (((kword_t)1U << 18) | 1U)
#define D_CHECKSUM 11U
#define TD_CHECKSUM 6U
#define TD_FIRST_ENTRY 7U

static kword_t media[8][6][0200];
static kword_t captured_handoff[3];
static unsigned int logical_to_unit[8] = { 4U, 1U, 6U, 2U, 5U, 3U, 0U, 7U };

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
        for (i = 0U; i < 0200U; ++i) {
                sum = rol36(sum);
                if (i != skip)
                        sum ^= p[i] & MASK36;
                sum = (sum + 1U) & MASK36;
        }
        return sum;
}

static void
make_member(unsigned int unit, unsigned int member, kword_t tdir_sum)
{
        unsigned int copy;

        for (copy = 1U; copy <= 2U; ++copy) {
                kword_t *p;

                p = media[unit][copy];
                memset(p, 0, sizeof(media[unit][copy]));
                p[0] = TSFS_MAGIC;
                p[1] = TSFS_VERSION;
                p[3] = 01234567UL;
                p[4] = 07654321UL;
                p[5] = 7U;
                p[6] = ((kword_t)8U << 18) | member;
                p[7] = TSFS_BLOCKS_PER_MEMBER;
                p[8] = ((kword_t)7U << 18) | 3U;
                p[9] = 1U;
                p[10] = tdir_sum;
                p[D_CHECKSUM] = checksum(p, D_CHECKSUM);
        }
}

static kword_t
make_metadata(void)
{
        kword_t *file;
        kword_t *td;
        kword_t file_sum;

        file = media[7][4];
        memset(file, 0, sizeof(media[7][4]));
        file_sum = checksum(file, 0200U);

        td = media[7][3];
        memset(td, 0, sizeof(media[7][3]));
        td[0] = TSDIR_MAGIC;
        td[1] = TSFS_VERSION;
        td[3] = 1U;
        td[TD_FIRST_ENTRY + 0U] = (kword_t)1U << 18;
        td[TD_FIRST_ENTRY + 1U] = ((kword_t)7U << 18) | 4U;
        td[TD_FIRST_ENTRY + 2U] = ((kword_t)1U << 18) | TSFS_FILE_WORDS;
        td[TD_FIRST_ENTRY + 3U] = 1U;
        td[TD_FIRST_ENTRY + 4U] = file_sum;
        td[TD_CHECKSUM] = checksum(td, TD_CHECKSUM);
        return td[TD_CHECKSUM];
}

unsigned int
module_service_get(unsigned int service)
{
        return service == MODULE_SERVICE_DTC_READ_BLOCK ? 1U : 0U;
}

kword_t
kinit_call_storage_io(unsigned int address, unsigned int unit, kword_t block,
    void *buffer)
{
        (void)address;
        if (unit >= 8U || block >= 6U)
                return (kword_t)-1;
        memcpy(buffer, media[unit][(unsigned int)block], sizeof(media[0][0]));
        return 0;
}

kword_t fs_tsfs_service_jump = 1U;

kword_t
kinit_call_fs_request(unsigned int address, const void *vp)
{
        const struct fs_mres_request *req;
        const kword_t *handoff;
        vnode_t *rootp;

        (void)address;
        req = (const struct fs_mres_request *)vp;
        handoff = (const kword_t *)(unsigned long)req->a;
        captured_handoff[0] = handoff[0];
        captured_handoff[1] = handoff[1];
        captured_handoff[2] = handoff[2];
        rootp = (vnode_t *)(unsigned long)req->d;
        *rootp = 1U;
        return 0;
}

int tsfs_boot_select(unsigned int ordinal);
int tsfs_boot_mount_root(void);

int
main(void)
{
        kword_t expected_map;
        kword_t tdir_sum;
        kword_t hi;
        unsigned int i;

        tdir_sum = make_metadata();
        for (i = 0U; i < 8U; ++i)
                make_member(logical_to_unit[i], i, tdir_sum);

        if (tsfs_boot_select(0U) != 0 || tsfs_boot_mount_root() != 0)
                return 1;
        expected_map = 0;
        for (i = 0U; i < 8U; ++i)
                expected_map |= (kword_t)logical_to_unit[i] << (3U * i);
        hi = (captured_handoff[0] >> 18) & 0777777UL;
        if ((unsigned int)(hi >> 15) != 7U ||
            (unsigned int)(hi & 077777U) != 1U ||
            (captured_handoff[0] & 0777777UL) != 4U ||
            captured_handoff[1] != expected_map || captured_handoff[2] != 0U)
                return 1;

        puts("daimos-tsfs-boot-eight-v1: PASS (KINIT accepts all eight members and preserves map)");
        return 0;
}
