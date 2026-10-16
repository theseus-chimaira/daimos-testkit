/* Native C99 attach oracle: the production packer must retain index:18,
 * PURE text:14 and the fifth mount-slot bit in existing credential storage.
 * Nonzero UID/GID/UMASK bits must never change as a side effect. */
#include "proc_swap.h"
#include "memfs.h"
#include "dtfs.h"
#include "tsfs.h"

static struct proc processes[2];
static struct proc_swap_record records[2];
static kword_t uarea[PROC_UAREA_WORDS];
struct proc *proc_table = processes;
struct proc_swap_record *proc_swap_records = records;
kword_t vfs_mount_limit = 26UL;
int __test_exit;

static int
verify(kword_t node, unsigned int mount, kword_t text)
{
        kword_t packed;
        kword_t cred;
        kword_t slot;

        cred = PROC_CRED_WORD(&processes[1]);
        if (proc_swap_attach(1, node, text, 1U) != 0)
                return 1;
        packed = records[1].state;
        slot = (kword_t)(mount - 1U);
        if ((packed & PROC_SWAP_INDEX_MASK) != VFS_INDEX(node) ||
            ((packed >> PROC_SWAP_MOUNT_SHIFT) & PROC_SWAP_MOUNT_MASK) !=
            (slot & PROC_SWAP_MOUNT_MASK) ||
            ((packed >> PROC_SWAP_TEXT_SHIFT) & PROC_SWAP_TEXT_MASK) != text ||
            ((PROC_CRED_WORD(&processes[1]) & PROC_SWAP_MOUNT_EXT_BIT) != 0UL)
                != ((slot & 020UL) != 0UL) ||
            (PROC_CRED_WORD(&processes[1]) & ~PROC_SWAP_MOUNT_EXT_BIT) !=
                (cred & ~PROC_SWAP_MOUNT_EXT_BIT))
                return 1;
        return 0;
}

int
main(void)
{
        vnode_t node26;
        vnode_t node10;
        kword_t before;

        processes[1].meta =
            ((kword_t)(unsigned long)uarea << PROC_HALF_SHIFT) |
            ((kword_t)PROC_F_UAREA << PROC_FLAGS_SHIFT);
        /* UID9/GID9/UMASK9, plus other reserved bits, are not backing. */
        PROC_CRED_WORD(&processes[1]) = 012345670123UL &
            ~PROC_SWAP_MOUNT_EXT_BIT;
        node26 = VFS_NODE(TSFS_PROVIDER, VFS_MOUNT_KIND(26U, 2U),
            PROC_SWAP_INDEX_MASK);
        node10 = VFS_NODE(TSFS_PROVIDER, VFS_MOUNT_KIND(10U, 2U),
            PROC_SWAP_INDEX_MASK);
        if (verify(node26, 26U, PROC_SWAP_TEXT_MASK) != 0)
                return 1;
        if (verify(node10, 10U, PROC_SWAP_TEXT_MASK) != 0)
                return 2;
        if (verify(node26, 26U, 01000UL) != 0)
                return 3;
        before = PROC_CRED_WORD(&processes[1]);
        if (proc_swap_attach(1, VFS_NODE(TSFS_PROVIDER,
            VFS_MOUNT_KIND(27U, 2U), 1UL), 01000UL, 1U) == 0 ||
            PROC_CRED_WORD(&processes[1]) != before)
                return 4;
        if (proc_swap_attach(1, node26, PROC_SWAP_TEXT_MASK + 1UL, 1U) == 0 ||
            PROC_CRED_WORD(&processes[1]) != before)
                return 5;
        /* RUN attaches before allocating the child's stable u-area. Only
         * SIDL may use scheduler RH bit0 as the transient extension carrier. */
        processes[1].meta = 0UL;
        processes[1].sched = PROC_SCHED_DEFAULT;
        PROC_SET_STATE(&processes[1], PROC_SIDL);
        if (proc_swap_attach(1, node26, 01000UL, 1U) != 0 ||
            (processes[1].sched & PROC_SWAP_STAGE_MOUNT_EXT_BIT) == 0UL ||
            PROC_STATE(&processes[1]) != PROC_SIDL)
                return 6;
        if (proc_swap_attach(1, node10, 01000UL, 1U) != 0 ||
            (processes[1].sched & PROC_SWAP_STAGE_MOUNT_EXT_BIT) != 0UL)
                return 7;
        if (proc_swap_attach(1, node26, 01000UL, 1U) != 0)
                return 8;
        PROC_SET_STATE(&processes[1], PROC_SRUN);
        if (proc_swap_attach(1, node10, 01000UL, 1U) == 0 ||
            (processes[1].sched & PROC_SWAP_STAGE_MOUNT_EXT_BIT) == 0UL)
                return 9;
        return 0;
}
