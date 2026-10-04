#include "dtfs.h"

int __test_exit;

static struct vfs_name oldname;
static struct vfs_name newname;
static unsigned int personality;
static int destination_exists;
static int set_name_calls;
static int foreign_calls;
static unsigned int seen_slot;
static int seen_its;
static vnode_t seen_commit;

int
dtfs_is_root(vnode_t node)
{
        (void)node;
        return 1;
}

int
dtfs_load(vnode_t node)
{
        (void)node;
        return 0;
}

int
dtfs_scan_slot(vnode_t dir, const struct vfs_name *name,
    unsigned int *slotp)
{
        (void)dir;
        if (name == &oldname) {
                if (slotp != 0)
                        *slotp = 5U;
                return 0;
        }
        if (name == &newname)
                return destination_exists ? 0 : -1;
        return -1;
}

unsigned int
dtfs_personality(vnode_t node)
{
        (void)node;
        return personality;
}

int
dtfs_foreign_set_name(unsigned int slot, const struct vfs_name *name,
    int its)
{
        if (name != &newname)
                return -1;
        ++foreign_calls;
        seen_slot = slot;
        seen_its = its;
        return 0;
}

void
dtfs_set_name(unsigned int slot, const struct vfs_name *name)
{
        if (name == &newname) {
                ++set_name_calls;
                seen_slot = slot;
        }
}

int
dtfs_commit(vnode_t node)
{
        seen_commit = node;
        return 0;
}

static int
check_case(unsigned int media, int want_native, int want_foreign, int want_its)
{
        vnode_t dir;
        int rc;

        dir = VFS_NODE_PACKED(DTFS_PROVIDER,
            (1U << VFS_MOUNT_SHIFT) | DTFS_KIND_ROOT, 0U);
        personality = media;
        destination_exists = 0;
        set_name_calls = 0;
        foreign_calls = 0;
        seen_slot = 0U;
        seen_its = -1;
        seen_commit = 0UL;
        rc = dtfs_rename(dir, &oldname, dir, &newname);
        if (rc != 0 || set_name_calls != want_native ||
            foreign_calls != want_foreign || seen_slot != 5U ||
            (want_foreign && seen_its != want_its) || seen_commit != dir)
                return 1;
        return 0;
}

int
main(void)
{
        vnode_t dir1;
        vnode_t dir2;

        if (check_case(0U, 1, 0, 0) != 0)
                return 1;
        if (check_case(010U, 0, 1, 0) != 0)
                return 2;
        if (check_case(020U, 0, 1, 1) != 0)
                return 3;

        dir1 = VFS_NODE_PACKED(DTFS_PROVIDER,
            (1U << VFS_MOUNT_SHIFT) | DTFS_KIND_ROOT, 0U);
        destination_exists = 1;
        personality = 0U;
        set_name_calls = foreign_calls = 0;
        if (dtfs_rename(dir1, &oldname, dir1, &newname) != -1 ||
            set_name_calls != 0 || foreign_calls != 0)
                return 4;

        dir2 = VFS_NODE_PACKED(DTFS_PROVIDER,
            (2U << VFS_MOUNT_SHIFT) | DTFS_KIND_ROOT, 0U);
        destination_exists = 0;
        set_name_calls = foreign_calls = 0;
        if (dtfs_rename(dir1, &oldname, dir2, &newname) != -1 ||
            set_name_calls != 0 || foreign_calls != 0)
                return 5;
        return 0;
}
