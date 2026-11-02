/* Actual production resident swap-record packing, C89 host regression. */
#include "proc_swap.h"
#include "vfs.h"
#include "memfs.h"
#include "d6fs_provider.h"
#include "tsfs.h"
#include <stdio.h>

static struct proc slots[3];
static struct proc_swap_record records[3];
struct proc *proc_table = slots;
struct proc_swap_record *proc_swap_records = records;
kword_t vfs_mount_limit = 26UL;

static int bad;
static void check(int ok, const char *msg)
{
        if (!ok) {
                ++bad;
                fprintf(stderr, "v960: %s\n", msg);
        }
}

int main(void)
{
        vnode_t node;
        kword_t expected;
        unsigned int mount;
        unsigned int provider;
        unsigned int kind;
        slots[1].sched = (kword_t)PROC_SIDL << PROC_STATE_SHIFT;
        for (mount = 1U; mount <= 26U; mount++) {
                provider = (mount & 1U) ? MEMFS_PROVIDER : D6FS_PROVIDER;
                kind = 1U;
                node = VFS_NODE(provider, VFS_MOUNT_KIND(mount, kind), 012345U);
                records[1].state = 0UL;
                slots[1].sched &= ~PROC_SWAP_STAGE_MOUNT_EXT_BIT;
                check(proc_swap_attach(1, node, 0700UL, 1U) == 0,
                    "valid SIDL backing refused");
                expected = 012345UL | ((kword_t)((mount - 1U) & 017U)
                    << PROC_SWAP_MOUNT_SHIFT) |
                    (0700UL << PROC_SWAP_TEXT_SHIFT);
                check(records[1].state == expected, "resident record mismatch");
                check(((slots[1].sched & PROC_SWAP_STAGE_MOUNT_EXT_BIT) != 0UL)
                    == (((mount - 1U) & 020U) != 0U), "mount bit mismatch");
        }
        node = VFS_NODE(D6FS_PROVIDER, VFS_MOUNT_KIND(1U, 1U), 1U);
        expected = records[1].state;
        check(proc_swap_attach(1, node, PROC_SWAP_TEXT_MASK + 1UL, 1U) == -1,
            "oversize PURE text accepted");
        check(records[1].state == expected, "rejected attach changed record");
        check(proc_swap_attach(1, VFS_NODE(3U, VFS_MOUNT_KIND(1U, 1U), 1U),
            0UL, 0U) == -1, "invalid provider accepted");
        check(proc_swap_attach(1, VFS_NODE(D6FS_PROVIDER,
            VFS_MOUNT_KIND(0U, 1U), 1U), 0UL, 0U) == -1,
            "unmounted backing accepted");
        check(proc_swap_attach(1, VFS_NODE(D6FS_PROVIDER,
            VFS_MOUNT_KIND(27U, 1U), 1U), 0UL, 0U) == -1,
            "out-of-range mount accepted");
        check(proc_swap_attach(1, VFS_NODE(D6FS_PROVIDER,
            VFS_MOUNT_KIND(1U, 2U), 1U), 0UL, 0U) == -1,
            "wrong local kind accepted");
        slots[1].sched = (kword_t)PROC_SRUN << PROC_STATE_SHIFT;
        check(proc_swap_attach(1, node, 1UL, 1U) == -1,
            "no-uarea non-SIDL accepted");
        check(!bad, "validation matrix failed");
        if (bad)
                return 1;
        puts("v960: resident mount extension and rejected attach immutability PASS");
        return 0;
}
