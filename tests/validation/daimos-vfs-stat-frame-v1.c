#include "vfs.h"

int __test_exit;

#define TEST_PROVIDER 4U
#define TEST_KIND_DIR 1U
#define TEST_NODE ((((kword_t)TEST_PROVIDER) << 30) | \
    (((kword_t)TEST_KIND_DIR) << 18) | (kword_t)2U)

int
main(void)
{
        vnode_t root;
        unsigned int ch;

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
