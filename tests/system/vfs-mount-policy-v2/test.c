#include <assert.h>
#include "vfs_mount_policy_v2.h"

int main(void)
{
        struct vfs_mount_policy_v2 p;
        unsigned int f;
        unsigned int i;

        assert(vfs_policy_v2_init(&p, 0U) == -1);
        assert(vfs_policy_v2_init(&p, 18U) == -1);
        assert(vfs_policy_v2_init(&p, 17U) == -1);
        assert(vfs_policy_v2_init(&p, 16U) == 0);
        for (i = 0U; i < 16U; ++i) {
                assert(vfs_policy_v2_get(&p, i, &f) == 0);
                assert(f == 0U);
        }
        assert(vfs_policy_v2_reserve(&p, 15U,
            VFS_POLICY_V2_RDONLY | VFS_POLICY_V2_SWAP) == 0);
        assert(vfs_policy_v2_get(&p, 15U, &f) == 0);
        assert(f == (VFS_POLICY_V2_RDONLY | VFS_POLICY_V2_SWAP));
        assert(vfs_policy_v2_reserve(&p, 0U, VFS_POLICY_V2_SWAP) == -1);
        assert(vfs_policy_v2_reserve(&p, 3U, VFS_POLICY_V2_LOGSTORE) == 0);
        assert(vfs_policy_v2_release(&p, 3U, VFS_POLICY_V2_SWAP) == -1);
        assert(vfs_policy_v2_get(&p, 3U, &f) == 0);
        assert(f == VFS_POLICY_V2_LOGSTORE);
        assert(vfs_policy_v2_release(&p, 15U, VFS_POLICY_V2_SWAP) == 0);
        assert(vfs_policy_v2_toggle_readonly(&p, 15U) == 0);
        assert(vfs_policy_v2_get(&p, 15U, &f) == 0 && f == 0U);
        assert(vfs_policy_v2_reserve(&p, 0U, VFS_POLICY_V2_SWAP) == 0);
        assert(vfs_policy_v2_clear(&p, 0U) == 0);
        assert(vfs_policy_v2_clear(&p, 3U) == 0);
        assert(p.swap == 0UL && p.logstore == 0UL);
        assert(vfs_policy_v2_get(&p, 16U, &f) == -1);
        assert(vfs_policy_v2_reserve(&p, 16U, 0U) == -1);
        assert(vfs_policy_v2_init(&p, 4U) == 0);
        assert(vfs_policy_v2_reserve(&p, 3U, VFS_POLICY_V2_RDONLY) == 0);
        assert(vfs_policy_v2_get(&p, 3U, &f) == 0 && f == 1U);
        return 0;
}
