/*
 * K05 v1808: a completed PURE restore must not be stranded because the
 * caller receives a lost-success reply. Both production restore functions
 * execute unmodified, including real PDP-6 MM owner transitions.
 * Fault wrappers modify ONLY the return to the original v1612 service.
 *
 * This source is appended to the v1384/v1611 source-linked C89 fixture.
 */
static unsigned int lost_prefix_reply_v1808;
static unsigned int lost_full_reply_v1808;
static unsigned int lost_prefix_hits_v1808;
static unsigned int lost_full_hits_v1808;

int
prefix_restore_reply_v1808(unsigned int slot,
    int (*loader)(kword_t, kword_t, kword_t, kword_t))
{
        int rc = proc_pure_restore_v1384(slot, loader);
        if (rc == MM_OK && lost_prefix_reply_v1808) {
                --lost_prefix_reply_v1808;
                ++lost_prefix_hits_v1808;
                return MM_ERR_BUSY;
        }
        return rc;
}

int
full_restore_reply_v1808(unsigned int slot,
    int (*loader)(kword_t, kword_t, kword_t, kword_t))
{
        int rc = proc_pure_ram_restore_v1391(slot, loader);
        if (rc == MM_OK && lost_full_reply_v1808) {
                --lost_full_reply_v1808;
                ++lost_full_hits_v1808;
                return MM_ERR_BUSY;
        }
        return rc;
}

static int
test_lost_restore_reply_v1808(unsigned int full)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *u = (kword_t *)(unsigned long)UAREA;
        kword_t destination = full ? RESTORE : SOURCE;
        int rc;

        reset_service_v1611();
        lost_prefix_reply_v1808 = full ? 0U : 1U;
        lost_full_reply_v1808 = full ? 1U : 0U;
        lost_prefix_hits_v1808 = 0U;
        lost_full_hits_v1808 = 0U;
        if (proc_pure_mres_reclaim_v1612(0200UL, 02000UL, 0U) != 0 ||
            !check_retained_v1611())
                return 1;
        PROC_SET_STATE(p, PROC_SRUN);
        proc_sched_cursor = PROC_SCHED_SWAP_REQUEST | SLOT;
        prefix_fallback_v1611 = full;
        rc = proc_pure_mres_service_v1612();
        if (lost_prefix_reply_v1808 || lost_full_reply_v1808 ||
            lost_prefix_hits_v1808 != (full ? 0U : 1U) ||
            lost_full_hits_v1808 != (full ? 1U : 0U) ||
            prefix_calls_v1611 != 1U ||
            full_calls_v1611 != full)
                return 2;
        /* A fully committed, unpinned PROCESS owner is the only legal
         * readiness witness; an error after commit cannot revoke it. */
        if (mm_extent_count != 1 ||
            MM_EXTENT_BASE(&mm_extents[0]) != destination ||
            MM_EXTENT_WORDS(&mm_extents[0]) != WORDS ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PROCESS ||
            MM_EXTENT_OWNER(&mm_extents[0]) != SLOT ||
            MM_EXTENT_PINNED(&mm_extents[0]) ||
            PROC_TRANSITION(p) || VM_PDP6_BASE(p) != destination ||
            u[PROC_SWAP_BACKING_OFFSET] ||
            proc_storage_expect_v30(SLOT, PROC_STORAGE_RESIDENT) != 0 ||
            !check_suffix_v1384() ||
            pi_depth_v1381 ||
            pi_disable_count_v1381 != pi_restore_count_v1381)
                return 3;
        if (rc != (int)(01000UL | SLOT) ||
            proc_sched_cursor != (01000UL | SLOT) ||
            proc_swap_pressure_ticks)
                return 4;  /* former v1612 lost-success dispatch bug */
        return 0;
}

int
main(void)
{
        int rc;

        rc = baseline_main_v1808();
        if (rc)
                return 01000 + rc;
        rc = test_lost_restore_reply_v1808(0U);
        if (rc)
                return 02000 + rc;
        rc = test_lost_restore_reply_v1808(1U);
        if (rc)
                return 03000 + rc;
        return 0;
}
