#include <assert.h>
#include "vfs_mount_layout_v3.h"

int
main(void)
{
        struct vfs_mount_layout_v3 l;
        unsigned int n;

        assert(vfs_mount_layout_v3(0U, &l) == -1);
        assert(vfs_mount_layout_v3(18U, &l) == -1);
        assert(vfs_mount_layout_v3(4U, 0) == -1);
        assert(vfs_mount_layout_v3(17U, &l) == -1);
        for (n = 1U; n <= 16U; ++n) {
                assert(vfs_mount_layout_v3(n, &l) == 0);
                assert(l.capacity == n);
                assert(l.target_off == 0U);
                assert(l.root_off == n);
                assert(l.reader_off == 2U * n);
                assert(l.media_off == 3U * n);
                assert(l.shape_off == 4U * n);
                assert(l.extent_off == 5U * n);
                assert(l.total_words == 6U * n);
        }
        return 0;
}
