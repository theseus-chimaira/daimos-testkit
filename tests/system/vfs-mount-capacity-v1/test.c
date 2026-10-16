#include <assert.h>
#include "vfs_mount_capacity_v1.h"

static unsigned int
capacity(unsigned int disks, unsigned int drums, unsigned int tapes,
    unsigned int disk_root, unsigned int drum_root, unsigned int tape_root,
    unsigned int memfs)
{
        struct vfs_mount_inventory_v1 inv;

        inv.disk_units = disks;
        inv.drum_units = drums;
        inv.tape_units = tapes;
        inv.root_disk_members = disk_root;
        inv.root_drum_members = drum_root;
        inv.root_tape_members = tape_root;
        inv.memfs_enabled = memfs;
        return vfs_mount_capacity_v1(&inv);
}

int
main(void)
{
        assert(capacity(0, 0, 4, 0, 0, 7, 0) == 2);
        assert(capacity(0, 0, 4, 0, 0, 3, 0) == 3);
        assert(capacity(4, 4, 8, 1, 0, 0, 1) == 17);
        assert(capacity(4, 4, 8, 15, 0, 0, 1) == 14);
        assert(capacity(4, 4, 8, 0, 1, 0, 1) == 17);
        assert(capacity(0, 0, 4, 0, 0, 16, 0) == 0);
        assert(capacity(4, 4, 8, 1, 1, 0, 0) == 0);
        assert(capacity(4, 4, 8, 0, 0, 0, 0) == 0);
        return 0;
}
