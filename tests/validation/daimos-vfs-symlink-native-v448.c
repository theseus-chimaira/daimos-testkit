#include "vfs.h"

int __test_exit;
extern kword_t vfs_mount_target_base, vfs_mount_root_base;
extern kword_t symlink_test_operation, symlink_test_argument_e;
extern kword_t symlink_test_output;

static kword_t targets[4], roots[4];
#define DIR_NODE ((((kword_t)4U) << 30) | (((kword_t)1U) << 18) | 2U)

int main(void)
{
        struct vfs_name name;
        kword_t target[3];
        vnode_t node;
        unsigned int i;

        vfs_mount_target_base = (kword_t)(unsigned long)targets;
        vfs_mount_root_base = (kword_t)(unsigned long)roots;
        name.chars = 3U;
        for (i = 0; i < VFS_NAME_WORDS; ++i) name.words[i] = 0;
        target[0] = 1U;
        target[1] = 0123456U;
        target[2] = 0;
        node = 0;
        symlink_test_operation = 0;
        symlink_test_argument_e = 0777;
        symlink_test_output = 0;
        if (vfs_symlink(DIR_NODE, &name, target, &node)) return 2;
        if (symlink_test_operation != 010U) return 3;
        if (symlink_test_argument_e != 0) return 4;
        if (symlink_test_output != (kword_t)(unsigned long)target) return 5;
        if (node == 0) return 6;
        return 0;
}
