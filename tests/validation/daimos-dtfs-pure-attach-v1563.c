/* Actual production C89 proc_swap_attach admission/rollback test. */
#include "proc_swap.h"
#include "vfs.h"
#include "dtfs.h"
#include "d6fs_provider.h"
#include <stdio.h>

static struct proc slots[3];
static struct proc_swap_record records[3];
static vnode_t roots[26];
struct proc *proc_table = slots;
struct proc_swap_record *proc_swap_records = records;
vnode_t *vfs_mount_root_base = roots;
kword_t vfs_mount_limit = 26UL;

static int quiescing;
static int checks;
static int errors;

/* Injection boundary: the actual native v1562 admission leaf is tested
 * separately against its real assembly. This fixture checks that C calls
 * that interface before writing ANY SIDL backing or slot extension. */
int
vfs_dtfs_owner_admit_v1562(vnode_t node)
{
        ++checks;
        if (VFS_PROVIDER(node) != DTFS_PROVIDER)
                return -1;
        return quiescing ? -1 : 0;
}

static void
check(int value, const char *message)
{
        if (!value) {
                ++errors;
                fprintf(stderr, "v1563: %s\n", message);
        }
}

static void
run_one(unsigned int mount)
{
        vnode_t node;
        kword_t old_record;
        kword_t old_sched;
        int old_checks;

        node = VFS_NODE(DTFS_PROVIDER,
            VFS_MOUNT_KIND(mount, 2U), 012345U);
        roots[mount - 1U] = VFS_NODE(DTFS_PROVIDER,
            VFS_MOUNT_KIND(mount, 1U), 0U);
        slots[1].sched = (kword_t)PROC_SIDL << PROC_STATE_SHIFT;
        slots[1].sched |= PROC_SWAP_STAGE_MOUNT_EXT_BIT;
        records[1].state = 012345670123UL;
        old_record = records[1].state;
        old_sched = slots[1].sched;
        quiescing = 1;
        old_checks = checks;
        check(proc_swap_attach(1, node, 0700UL, 1U) == -1,
            "quiescent PURE executable was attached");
        check(checks == old_checks + 1, "missing DTFS admission call");
        check(records[1].state == old_record,
            "refused PURE attach changed backing record");
        check(slots[1].sched == old_sched,
            "refused PURE attach changed SIDL staging bit");
        check(proc_swap_attach(1, node, 0UL, 0U) == -1,
            "quiescent non-PURE RUN executable was attached");
        check(records[1].state == old_record,
            "refused non-PURE attach changed backing record");

        quiescing = 0;
        check(proc_swap_attach(1, node, 0700UL, 1U) == 0,
            "healthy DTFS PURE executable refused");
        check((slots[1].sched & PROC_SWAP_STAGE_MOUNT_EXT_BIT) ==
            (((mount - 1U) & 020U) != 0U),
            "accepted SIDL fifth mount bit incorrect");
        check(records[1].state ==
            (012345UL | ((kword_t)((mount - 1U) & 017U) <<
              PROC_SWAP_MOUNT_SHIFT) | (0700UL << PROC_SWAP_TEXT_SHIFT)),
            "accepted PURE backing record incorrect");
}

int
main(void)
{
        vnode_t node;
        int saved;

        run_one(1U);
        run_one(16U);
        run_one(17U);
        run_one(26U);
        quiescing = 1;
        saved = checks;
        roots[1] = VFS_NODE(D6FS_PROVIDER, VFS_MOUNT_KIND(2U, 1U), 0U);
        node = VFS_NODE(D6FS_PROVIDER, VFS_MOUNT_KIND(2U, 1U), 1U);
        check(proc_swap_attach(1, node, 0123UL, 1U) == 0,
            "unrelated D6FS backing blocked by DTFS seal");
        check(checks == saved, "unrelated provider called DTFS gate");
        check(errors == 0, "attachment validation matrix failed");
        if (errors != 0)
                return 1;
        puts("v1563: production PURE/RUN attachment admission PASS");
        return 0;
}
