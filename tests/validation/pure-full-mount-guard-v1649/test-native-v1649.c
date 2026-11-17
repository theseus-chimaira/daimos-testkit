/*
 * v1649: real compiled v1391 FULL loader with simultaneously pinned
 * RAW source and PROCESS destination, and the production PDP-6
 * executable-backing and mount-owner scanners.
 *
 * This is a native source-linked transaction test, NOT an independent
 * physical DTFS unmount or two-process PI6 interleaving.
 */

extern int proc_swap_mount_busy(unsigned int mount);
extern int proc_swap_backing_busy(vnode_t node);
unsigned int proc_high_slot = SLOTS;
static unsigned int scans_v1649;

static int
guarded_full_loader_v1649(kword_t backing, kword_t base,
    kword_t stable, kword_t capacity)
{
        struct proc *p = &process_slots[SLOT];
        kword_t src_span, src_meta, dst_span, dst_meta;
        vnode_t exact, different;

        if (backing != BACKING || base != RESTORE ||
            stable != UAREA || capacity != WORDS ||
            proc_current_slot != 0UL || !PROC_TRANSITION(p) ||
            VM_PDP6_BASE(p) != 0UL ||
            proc_storage_expect_v30(SLOT, PROC_STORAGE_PACKED) != 0 ||
            mm_extent_count != 2 ||
            MM_EXTENT_BASE(&mm_extents[0]) != SOURCE + OMIT ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PACKED_PROCESS ||
            MM_EXTENT_OWNER(&mm_extents[0]) != SLOT ||
            MM_EXTENT_WORDS(&mm_extents[0]) != SUFFIX ||
            MM_EXTENT_PINNED(&mm_extents[0]) != 1U ||
            MM_EXTENT_BASE(&mm_extents[1]) != RESTORE ||
            MM_EXTENT_TYPE(&mm_extents[1]) != MM_TYPE_PROCESS ||
            MM_EXTENT_OWNER(&mm_extents[1]) != SLOT ||
            MM_EXTENT_WORDS(&mm_extents[1]) != WORDS ||
            MM_EXTENT_PINNED(&mm_extents[1]) != 1U ||
            !check_suffix_v1384())
                return -1;

        src_span = mm_extents[0].span;
        src_meta = mm_extents[0].meta;
        dst_span = mm_extents[1].span;
        dst_meta = mm_extents[1].meta;

        /*
         * The original DTFS public mount is 1, provider 5, local
         * file kind 2.  The backed DXR2 has file index 012345.
         */
        exact = VFS_NODE(5U, VFS_MOUNT_KIND(1U, 2U), 012345UL);
        different = VFS_NODE(5U, VFS_MOUNT_KIND(1U, 2U), 012346UL);
        if (proc_swap_mount_busy(1U) != 1 ||
            proc_swap_backing_busy(exact) != 1 ||
            proc_swap_mount_busy(2U) != 0 ||
            proc_swap_backing_busy(different) != 0)
                return -1;
        if (mm_extent_count != 2 ||
            mm_extents[0].span != src_span ||
            mm_extents[0].meta != src_meta ||
            mm_extents[1].span != dst_span ||
            mm_extents[1].meta != dst_meta ||
            swap_slots[SLOT].state != BACKING ||
            !PROC_TRANSITION(p))
                return -1;

        ++scans_v1649;
        return accept_payload_v1395(backing, base, stable, capacity);
}

static int
case_guarded_full_v1649(void)
{
        vnode_t old_root = vfs_mount_root_base[0];
        struct proc *p = &process_slots[SLOT];
        int rc;

        fault_kind_v1395 = 0U;
        fault_kind_v1648 = 0U;
        scans_v1649 = 0U;
        reset_prefix_v1384();
        vfs_mount_root_base[0] =
            VFS_NODE(5U, VFS_MOUNT_KIND(1U, 2U), 0U);
        proc_current_slot = 0UL;
        if (proc_pure_ram_drop_v1381(SLOT) != MM_OK) {
                vfs_mount_root_base[0] = old_root;
                return 1;
        }
        PROC_SET_TRANSITION(p);
        rc = proc_pure_ram_restore_v1391(SLOT,
            guarded_full_loader_v1649);
        vfs_mount_root_base[0] = old_root;
        if (rc != MM_OK || scans_v1649 != 1U)
                return 2;
        if (!check_restored_v1648())
                return 3;
        return 0;
}

int
main(void)
{
        int rc;

        rc = baseline_main_v1648();
        if (rc != 0)
                return rc;
        rc = case_guarded_full_v1649();
        if (rc != 0)
                return 02000 + rc;
        return 0;
}
