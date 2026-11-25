/* Actual shared image bridge, controlled serialized provider boundary. */
static unsigned int checks_v1925, fail_v1925, bad_order_v1925;

int
media_check_v1925(vnode_t node)
{
        ++checks_v1925;
        if (node != expected_vnode_v1385 || pi_depth_v1381 ||
            (checks_v1925 == 1U && (header_reads_v1385 || payload_reads_v1385)) ||
            (checks_v1925 == 2U && payload_reads_v1385 != 1U))
                bad_order_v1925 = 1U;
        if (fail_v1925 == 3U && checks_v1925 == 2U)
                roots_v1385[0] ^= 1UL;
        return checks_v1925 == fail_v1925 ? -1 : 0;
}

static int
bridge_case_v1925(unsigned int full, unsigned int fault, unsigned int provider)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *u = (kword_t *)(unsigned long)UAREA;
        unsigned int expected_checks = (provider == 5U || provider == 6U) ? 2U : 0U;
        int rc;
        vnode_t root = VFS_NODE(provider, VFS_MOUNT_KIND(1U, 1U), 1U);
        reset_prefix_v1384();
        roots_v1385[0] = root;
        shape_v1926[0] = 1UL;
        extent_v1926[0] = 2UL;
        media_v1926[0] = provider == 7U ? (020UL << 18U) | 0200UL : 0UL;
        u[PROC_CRED_OFFSET] = (kword_t)provider << PROC_SWAP_PROVIDER_SHIFT_V1924;
        expected_vnode_v1385 = VFS_NODE(provider, VFS_MOUNT_KIND(1U, 1U + (provider & 1U)), 012345UL);
        if (proc_pure_ram_drop_v1381(SLOT) != MM_OK)
                return 1;
        PROC_SET_TRANSITION(p);
        checks_v1925 = bad_order_v1925 = 0U;
        fail_v1925 = fault;
        read_mode_v1385 = 0;
        header_reads_v1385 = payload_reads_v1385 = compressed_calls_v1391 = 0U;
        if (full)
                rc = proc_pure_ram_restore_v1391(SLOT, exec_image_full_bounded_v1391);
        else
                rc = proc_pure_restore_v1384(SLOT, exec_image_prefix_backing_v1386);
        if (bad_order_v1925 || checks_v1925 != (fault == 1U ? 1U : expected_checks))
                return 2;
        if (fault) {
                if (rc != MM_ERR_INVAL || mm_extent_count != 1 ||
                    MM_EXTENT_BASE(&mm_extents[0]) != SOURCE + OMIT ||
                    MM_EXTENT_WORDS(&mm_extents[0]) != SUFFIX ||
                    MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PACKED_PROCESS ||
                    MM_EXTENT_PINS(&mm_extents[0]) || !PROC_TRANSITION(p) ||
                    VM_PDP6_BASE(p) || !check_suffix_v1384() ||
                    u[PROC_SWAP_BACKING_OFFSET] != BACKING || u[PROC_FINALIZE_OFFSET] ||
                    proc_storage_expect_v30(SLOT, PROC_STORAGE_PACKED))
                        return 3;
                if (payload_reads_v1385 != (fault == 1U ? 0U : 1U))
                        return 4;
                /* Exact original backing returns: a fresh load can commit. */
                roots_v1385[0] = root;
                checks_v1925 = fail_v1925 = bad_order_v1925 = 0U;
                header_reads_v1385 = payload_reads_v1385 = 0U;
                if (full)
                        rc = proc_pure_ram_restore_v1391(SLOT, exec_image_full_bounded_v1391);
                else
                        rc = proc_pure_restore_v1384(SLOT, exec_image_prefix_backing_v1386);
                if (checks_v1925 != 2U || bad_order_v1925)
                        return 5;
        }
        if (rc != MM_OK || PROC_TRANSITION(p) || mm_extent_count != 1 ||
            VM_PDP6_BASE(p) != (full ? RESTORE : SOURCE) || !check_suffix_v1384())
                return 6;
        return 0;
}

int
main(void)
{
        unsigned int full, fault;
        int rc;
        for (full = 0U; full <= 1U; ++full) {
                for (fault = 0U; fault <= 3U; ++fault) {
                        rc = bridge_case_v1925(full, fault, 5U);
                        if (rc) return (int)(0100U + full * 0100U + fault * 010U) + rc;
                }
                for (fault = 0U; fault <= 3U; ++fault) {
                        rc = bridge_case_v1925(full, fault, 6U);
                        if (rc) return (int)(0300U + full * 0100U + fault * 010U) + rc;
                }
                rc = bridge_case_v1925(full, 0U, 7U);
                if (rc) return (int)(0500U + full * 010U) + rc;
        }
        return 0;
}
