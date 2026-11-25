/* Shared production decoder/loader with provider changes during real reads. */
static int
case_v1923(unsigned int mode, unsigned int full, unsigned int mount)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *u = (kword_t *)(unsigned long)UAREA;
        vnode_t root;
        kword_t state;
        unsigned int i;
        int rc;
        reset_prefix_v1384();
        for (i = 0U; i < 26U; ++i)
                roots_v1385[i] = 0UL;
        root = VFS_NODE(6U, VFS_MOUNT_KIND(mount, 1U), 1U);
        roots_v1385[mount - 1U] = root;
        expected_vnode_v1385 = VFS_NODE(6U, VFS_MOUNT_KIND(mount, 1U), 012345U);
        state = ((kword_t)TEXT << PROC_SWAP_TEXT_SHIFT) |
            (((kword_t)(mount - 1U) & PROC_SWAP_MOUNT_MASK) << PROC_SWAP_MOUNT_SHIFT) | 012345UL;
        swap_slots[SLOT].state = state;
        if (mount > 16U)
                u[PROC_CRED_OFFSET] |= PROC_SWAP_MOUNT_EXT_BIT;
        if (proc_pure_ram_drop_v1381(SLOT) != MM_OK)
                return 1;
        PROC_SET_TRANSITION(p);
        read_mode_v1385 = (int)mode;
        payload_reads_v1385 = header_reads_v1385 = compressed_calls_v1391 = 0U;
        if (full)
                rc = proc_pure_ram_restore_v1391(SLOT, exec_image_full_bounded_v1391);
        else
                rc = proc_pure_restore_v1384(SLOT, exec_image_prefix_backing_v1386);
        if (rc != MM_ERR_INVAL || VM_PDP6_BASE(p) || !PROC_TRANSITION(p) ||
            mm_extent_count != 1 || MM_EXTENT_BASE(&mm_extents[0]) != SOURCE + OMIT ||
            MM_EXTENT_WORDS(&mm_extents[0]) != SUFFIX ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PACKED_PROCESS ||
            MM_EXTENT_PINS(&mm_extents[0]) || !check_suffix_v1384() ||
            u[PROC_SWAP_BACKING_OFFSET] != state || swap_slots[SLOT].state != state ||
            u[PROC_FINALIZE_OFFSET] || proc_storage_expect_v30(SLOT, PROC_STORAGE_PACKED))
                return 2;
        if (payload_reads_v1385 != (mode >= 10U ? 1U : 0U) || compressed_calls_v1391)
                return 3;
        /* Recover after the original source becomes available again. */
        roots_v1385[mount - 1U] = root;
        read_mode_v1385 = 0;
        if (full)
                rc = proc_pure_ram_restore_v1391(SLOT, exec_image_full_bounded_v1391);
        else
                rc = proc_pure_restore_v1384(SLOT, exec_image_prefix_backing_v1386);
        if (rc != MM_OK || PROC_TRANSITION(p) || !check_suffix_v1384() ||
            VM_PDP6_BASE(p) != (full ? RESTORE : SOURCE))
                return 4;
        return 0;
}

static int
unpack_v1923(void)
{
        kword_t *u = (kword_t *)(unsigned long)UAREA;
        kword_t backing = BACKING;
        u[PROC_CRED_OFFSET] = (kword_t)6UL << PROC_SWAP_PROVIDER_SHIFT_V1924;
        roots_v1385[0] = VFS_NODE(6U, VFS_MOUNT_KIND(2U, 1U), 1U);
        if (proc_swap_unpack_backing(backing, UAREA)) return 1;
        vfs_mount_root_base = (vnode_t *)0;
        if (proc_swap_unpack_backing(backing, UAREA)) return 2;
        vfs_mount_root_base = roots_v1385;
        roots_v1385[0] = VFS_NODE(6U, VFS_MOUNT_KIND(1U, 1U), 1U);
        if (proc_swap_unpack_backing(backing, 0UL)) return 3;
        if (proc_swap_unpack_backing(0UL, UAREA)) return 4;
        if (proc_swap_unpack_backing(backing, UAREA) !=
            VFS_NODE(6U, VFS_MOUNT_KIND(1U, 1U), 012345UL)) return 5;
        return 0;
}

int
main(void)
{
        unsigned int mode, full;
        int rc = unpack_v1923();
        if (rc) return 0100 + rc;
        for (full = 0U; full <= 1U; ++full) {
                for (mode = 8U; mode <= 12U; ++mode) {
                        rc = case_v1923(mode, full, full ? 18U : 1U);
                        if (rc) return (int)(02000U * full + mode * 0100U) + rc;
                }
        }
        return 0;
}
