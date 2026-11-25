/* Real admission, DROP, PREFIX, FULL and unpacker; no model owner logic. */
static int
provider_case_v1924(unsigned int provider, unsigned int phase)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *u = (kword_t *)(unsigned long)UAREA;
        kword_t span, meta;
        vnode_t original = VFS_NODE(6U, VFS_MOUNT_KIND(1U, 1U), 1U);
        vnode_t replacement = VFS_NODE(provider, VFS_MOUNT_KIND(1U, 1U), 1U);
        int rc;
        reset_prefix_v1384();
        roots_v1385[0] = original;
        expected_vnode_v1385 = VFS_NODE(6U, VFS_MOUNT_KIND(1U, 1U), 012345UL);
        if (phase && proc_pure_ram_drop_v1381(SLOT) != MM_OK)
                return 1;
        PROC_SET_TRANSITION(p);
        span = mm_extents[0].span;
        meta = mm_extents[0].meta;
        roots_v1385[0] = replacement;
        if (phase == 0U)
                rc = proc_pure_ram_drop_v1381(SLOT);
        else if (phase == 1U)
                rc = proc_pure_restore_v1384(SLOT, exec_image_prefix_backing_v1386);
        else
                rc = proc_pure_ram_restore_v1391(SLOT, exec_image_full_bounded_v1391);
        if (rc != MM_ERR_INVAL || mm_extent_count != 1 ||
            !check_no_mutation_v1381(span, meta) || !check_suffix_v1384() ||
            !PROC_TRANSITION(p) || u[PROC_FINALIZE_OFFSET] ||
            u[PROC_SWAP_BACKING_OFFSET] != (phase ? BACKING : 0UL) ||
            VM_PDP6_BASE(p) != (phase ? 0UL : SOURCE) ||
            alloc_count_v1381 || free_count_v1381)
                return 2;
        if (proc_swap_unpack_backing(BACKING, UAREA))
                return 3;
        roots_v1385[0] = original;
        if (proc_swap_unpack_backing(BACKING, UAREA) != expected_vnode_v1385)
                return 4;
        return 0;
}

int
main(void)
{
        unsigned int provider, phase;
        int rc;
        for (provider = 4U; provider <= 7U; ++provider) {
                if (provider == 6U) continue;
                for (phase = 0U; phase <= 2U; ++phase) {
                        rc = provider_case_v1924(provider, phase);
                        if (rc) return (int)(provider * 0100U + phase * 010U) + rc;
                }
        }
        return 0;
}
