/* v1679 PDP-6 native MM: repeated original pin/rebase refusal.
 * The second real owner must remain resident, unpinned, with complete
 * image and source provenance. The first owner remains independently
 * eligible for READY_ONCE and the second remains retryable after the
 * MM geometry/pin fault disappears. All production code is linked.
 */
static int
case_persistent_v1679(unsigned int kind)
{
        struct proc *p = &process_slots[SLOT];
        struct proc *q = &process_slots[SLOT2_V1677];
        unsigned int attempt;
        int rc;

        setup_two_v1678();
        pin_fault_v1678 = (kind == 1U);
        rebase_fault_v1678 = (kind == 2U);
        for (attempt = 0U; attempt < 3U; ++attempt) {
                /* After the first iteration, only the second source
                 * remains a candidate. A persistent MM error cannot
                 * consume a second PIN/TRANSITION or corrupt a suffix.
                 */
                rc = proc_pure_mres_reclaim_v1611(0200UL, 02000UL,
                    attempt ? SLOT : 0U);
                if (rc != -1 ||
                    pin_hits_v1678 != (kind == 1U ? attempt + 1U : 0U) ||
                    rebase_hits_v1678 != (kind == 2U ? attempt + 1U : 0U) ||
                    !resident_two_v1678() ||
                    !check_owner_v1677(SLOT, SOURCE + OMIT, SUFFIX,
                        MM_TYPE_PACKED_PROCESS, 0U) ||
                    PROC_TRANSITION(p) || VM_PDP6_BASE(p) ||
                    pi_depth_v1381 ||
                    pi_disable_count_v1381 != pi_restore_count_v1381)
                        return 1;
        }
        /* Reclaim errors in a separate owner cannot prevent the
         * original slot-0 service from restoring its healthy peer. */
        PROC_SET_STATE(p, PROC_SRUN);
        proc_sched_cursor = PROC_SCHED_SWAP_REQUEST | SLOT;
        rc = proc_pure_mres_service_v1611();
        if (rc != (int)(01000UL | SLOT) ||
            proc_sched_cursor != (01000UL | SLOT) ||
            PROC_TRANSITION(p) || VM_PDP6_BASE(p) != SOURCE ||
            !check_owner_v1677(SLOT, SOURCE, WORDS,
                MM_TYPE_PROCESS, 0U) || !resident_two_v1678())
                return 2;
        /* Fault still active: another failed scan cannot consume the
         * unpinned RESIDENT owner or accidentally re-publish it. */
        rc = proc_pure_mres_reclaim_v1611(0200UL, 02000UL, SLOT);
        if (rc != -1 || !resident_two_v1678() ||
            pin_hits_v1678 != (kind == 1U ? 4U : 0U) ||
            rebase_hits_v1678 != (kind == 2U ? 4U : 0U))
                return 3;
        /* Once the real MM refusal is lifted, the second original
         * owner must be independently reclaimable and restorable. */
        pin_fault_v1678 = 0U;
        rebase_fault_v1678 = 0U;
        PROC_SET_STATE(p, PROC_SLEEP);
        rc = proc_pure_mres_reclaim_v1611(0200UL, 02000UL, SLOT);
        if (rc != -1 ||
            !check_owner_v1677(SLOT2_V1677,
                SOURCE2_V1677 + OMIT, SUFFIX,
                MM_TYPE_PACKED_PROCESS, 0U) ||
            PROC_TRANSITION(q) || VM_PDP6_BASE(q) ||
            proc_storage_expect_v30(SLOT2_V1677,
                PROC_STORAGE_PACKED))
                return 4;
        PROC_SET_STATE(q, PROC_SRUN);
        proc_sched_cursor = PROC_SCHED_SWAP_REQUEST | SLOT2_V1677;
        rc = proc_pure_mres_service_v1611();
        if (rc != (int)(01000UL | SLOT2_V1677) ||
            proc_sched_cursor != (01000UL | SLOT2_V1677) ||
            PROC_TRANSITION(q) ||
            VM_PDP6_BASE(q) != SOURCE2_V1677 ||
            !check_owner_v1677(SLOT2_V1677, SOURCE2_V1677,
                WORDS, MM_TYPE_PROCESS, 0U) ||
            pi_depth_v1381 ||
            pi_disable_count_v1381 != pi_restore_count_v1381)
                return 5;
        return 0;
}

int
main(void)
{
        unsigned int kind;
        int rc;
        for (kind = 1U; kind <= 2U; ++kind) {
                rc = case_persistent_v1679(kind);
                if (rc)
                        return (int)(03000U + kind * 0100U +
                            (unsigned int)rc);
        }
        return 0;
}
