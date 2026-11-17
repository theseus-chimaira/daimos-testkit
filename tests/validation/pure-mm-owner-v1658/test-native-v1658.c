/* Source-linked PDP-6 v1658 fast-commit and DROP refusal tests.
 * The v1384/v1612 native fixture and real MM assembler are linked by
 * run-v1658.sh. Faults affect only the v1381 DROP unpin call.
 */
static unsigned int drop_fault_v1658;
static unsigned int drop_hits_v1658;

int
mm_unpin_fault_v1658(kword_t base)
{
        if (base == SOURCE + OMIT && drop_fault_v1658) {
                ++drop_hits_v1658;
                if (drop_fault_v1658 == 1U) {
                        /* Operation committed, but its return was lost. */
                        if (mm_unpin(base) != MM_OK)
                                return MM_ERR_INVAL;
                }
                return MM_ERR_BUSY;
        }
        return mm_unpin(base);
}

static int
fast_commit_v1658(void)
{
        struct proc *p = &process_slots[SLOT];
        int rc;

        reset_service_v1611();
        if (proc_pure_mres_reclaim_v1611(0200UL, 02000UL, 0U) != 0 ||
            !check_retained_v1611())
                return 1;
        PROC_SET_STATE(p, PROC_SRUN);
        proc_sched_cursor = PROC_SCHED_SWAP_REQUEST | SLOT;
        rc = proc_pure_mres_service_v1611();
        if (rc != (int)(01000U | SLOT) || PROC_TRANSITION(p) ||
            mm_extent_count != 1 ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PROCESS ||
            MM_EXTENT_PINNED(&mm_extents[0]) != 0U ||
            VM_PDP6_BASE(p) != SOURCE ||
            proc_storage_expect_v30(SLOT, PROC_STORAGE_RESIDENT) != 0 ||
            !check_suffix_v1384())
                return 2;
        /* The commit consumed its pin; a second unpin MUST fail. */
        if (mm_unpin(SOURCE) != MM_ERR_INVAL ||
            MM_EXTENT_PINNED(&mm_extents[0]) != 0U)
                return 3;
        return 0;
}

static int
drop_refusal_v1658(unsigned int kind)
{
        struct proc *p = &process_slots[SLOT];
        int rc;

        reset_service_v1611();
        drop_fault_v1658 = kind;
        drop_hits_v1658 = 0U;
        rc = proc_pure_mres_reclaim_v1611(0200UL, 02000UL, 0U);
        drop_fault_v1658 = 0U;
        if (drop_hits_v1658 != 1U ||
            mm_extent_count != 1 ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PACKED_PROCESS ||
            MM_EXTENT_WORDS(&mm_extents[0]) != SUFFIX ||
            VM_PDP6_BASE(p) ||
            proc_storage_expect_v30(SLOT, PROC_STORAGE_PACKED) != 0 ||
            !check_suffix_v1384())
                return 1;
        if (kind == 1U) {
                /* A completed unpin and an exact PACKED owner may be
                 * verified and unlocked without a second MM unpin.
                 */
                if (rc != 0 || !check_retained_v1611() ||
                    compact_calls_v1611 != 2U)
                        return 2;
        } else {
                /* A genuinely refused pin remains transition-held.
                 * No READY_ONCE, freeing, guessing or blind unpin.
                 */
                if (rc != -1 || !PROC_TRANSITION(p) ||
                    MM_EXTENT_PINNED(&mm_extents[0]) != 1U ||
                    proc_sched_cursor || proc_swap_pressure_ticks)
                        return 3;
                (void)proc_pure_mres_reclaim_v1611(0200UL, 02000UL, 0U);
                if (!PROC_TRANSITION(p) ||
                    MM_EXTENT_PINNED(&mm_extents[0]) != 1U ||
                    drop_hits_v1658 != 1U)
                        return 4;
        }
        return 0;
}

int
main(void)
{
        int rc;

        rc = baseline_main_v1658();
        if (rc)
                return 01000 + rc;
        rc = fast_commit_v1658();
        if (rc)
                return 02000 + rc;
        rc = drop_refusal_v1658(1U);
        if (rc)
                return 03000 + rc;
        rc = drop_refusal_v1658(2U);
        if (rc)
                return 04000 + rc;
        return 0;
}
