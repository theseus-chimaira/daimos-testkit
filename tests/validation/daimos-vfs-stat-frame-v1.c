#include "vfs.h"

int __test_exit;

/* KINIT installs these before any mount. This standalone oracle must do the
 * same now that obsolete resident fallback tables have been removed. */
extern kword_t vfs_mount_target_base;
extern kword_t vfs_mount_root_base;
static kword_t test_mount_targets[4];
static kword_t test_mount_roots[4];

#define TEST_PROVIDER 4U
#define TEST_KIND_DIR 1U
#define TEST_NODE ((((kword_t)TEST_PROVIDER) << 30) | \
    (((kword_t)TEST_KIND_DIR) << 18) | (kword_t)2U)

int
main(void)
{
        vnode_t root;
        unsigned int ch;

        vfs_mount_target_base = (kword_t)(unsigned long)test_mount_targets;
        vfs_mount_root_base = (kword_t)(unsigned long)test_mount_roots;

        /* The STAT stub stores all six vfs_stat words.  These calls therefore
         * detect a local frame that overlaps the PUSHJ return word. */
        root = VFS_NODE_NONE;
        if (vfs_mount(TEST_NODE, TEST_PROVIDER, TEST_KIND_DIR, 0U,
            VFS_MOUNT_RW, &root) != 0 || root == VFS_NODE_NONE)
                return 1;

        ch = 0U;
        if (vfs_readchar(TEST_NODE, 0U, &ch) != -1)
                return 2;
        if (vfs_writechar(TEST_NODE, 0U, (unsigned int)'A') != -1)
                return 3;
        return 0;
}
