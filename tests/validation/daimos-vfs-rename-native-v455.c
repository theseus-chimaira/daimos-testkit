#include "vfs.h"

int __test_exit;
extern kword_t vfs_mount_root_base, vfs_mount_target_base;
extern kword_t rename_test_calls, rename_test_op;
static kword_t roots[4], targets[4];
#define NODE(p,m,k) ((((kword_t)(p)) << 30) | (((kword_t)(m)) << 24) | (((kword_t)(k)) << 18) | 2U)

int main(void)
{
        struct vfs_name a, b;
        unsigned int i;
        vfs_mount_root_base = (kword_t)(unsigned long)roots;
        vfs_mount_target_base = (kword_t)(unsigned long)targets;
        for (i = 0; i < VFS_NAME_WORDS; ++i) a.words[i] = b.words[i] = 0;
        a.chars = b.chars = 1U;
        rename_test_calls = 0;
        if (vfs_rename(NODE(4,0,1), &a, NODE(4,0,2), &b)) return 1;
        if (rename_test_calls != 1 || rename_test_op != 012U) return 2;
        if (vfs_rename(NODE(4,0,1), &a, NODE(5,0,1), &b) != -1) return 3;
        if (vfs_rename(NODE(4,0,1), &a, NODE(4,1,1), &b) != -1) return 4;
        if (rename_test_calls != 1) return 5;
        return 0;
}
