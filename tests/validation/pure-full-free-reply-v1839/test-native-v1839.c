/*
 * K05 v1839: the PACKED source can have been physically retired even
 * though its mm_free() return was lost. The restored destination is then
 * the sole surviving VM owner, not disposable rollback scratch.
 *
 * Appended to the actual v1384/v1395 native transaction fixture.
 */
static unsigned int lost_packed_free_v1839;
static unsigned int lost_packed_hits_v1839;
static unsigned int refuse_packed_free_v1839;
static unsigned int foreign_packed_free_v1839;

int
mm_free_reply_v1839(kword_t base, unsigned int type, unsigned int owner)
{
        int rc;

        if (base == SOURCE + OMIT && type == MM_TYPE_PACKED_PROCESS &&
            owner == SLOT) {
                if (refuse_packed_free_v1839) {
                        --refuse_packed_free_v1839;
                        return MM_ERR_BUSY; /* no source mutation */
                }
                if (foreign_packed_free_v1839) {
                        int i;

                        --foreign_packed_free_v1839;
                        for (i = 0; i < mm_extent_count; ++i) {
                                struct mm_extent *e = &mm_extents[i];
                                if (MM_EXTENT_BASE(e) == base) {
                                        e->meta = (e->meta &
                                            ~MM_OWNER_MASK) | (SLOT + 1U);
                                        return MM_ERR_BUSY;
                                }
                        }
                        return MM_ERR_INVAL;
                }
        }
        rc = mm_free_fault_v1395(base, type, owner);

        if (rc == MM_OK && lost_packed_free_v1839 &&
            base == SOURCE + OMIT && type == MM_TYPE_PACKED_PROCESS &&
            owner == SLOT) {
                --lost_packed_free_v1839;
                ++lost_packed_hits_v1839;
                return MM_ERR_BUSY; /* only the reply is lost */
        }
        return rc;
}

static int
test_lost_packed_free_v1839(void)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *u = (kword_t *)(unsigned long)UAREA;
        int rc;

        fault_kind_v1395 = 0U;
        fault_calls_v1395 = 0U;
        reset_prefix_v1384();
        if (proc_pure_ram_drop_v1381(SLOT) != MM_OK ||
            mm_extent_count != 1 || !check_suffix_v1384())
                return 1;

        PROC_SET_TRANSITION(p);
        lost_packed_free_v1839 = 1U;
        lost_packed_hits_v1839 = 0U;
        rc = proc_pure_ram_restore_v1391(SLOT, accept_payload_v1395);
        if (lost_packed_hits_v1839 != 1U || lost_packed_free_v1839)
                return 2;
        /* The MM free succeeded before its return was falsified. The
         * old rollback incorrectly destroys the only complete APR.
         */
        if (mm_extent_count != 1 ||
            MM_EXTENT_BASE(&mm_extents[0]) != RESTORE ||
            MM_EXTENT_WORDS(&mm_extents[0]) != WORDS ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PROCESS ||
            MM_EXTENT_OWNER(&mm_extents[0]) != SLOT ||
            MM_EXTENT_PINNED(&mm_extents[0]))
                return 3;
        if (rc != MM_OK || PROC_TRANSITION(p) ||
            VM_PDP6_BASE(p) != RESTORE ||
            u[PROC_SWAP_BACKING_OFFSET] ||
            proc_storage_expect_v30(SLOT, PROC_STORAGE_RESIDENT) != 0 ||
            !check_suffix_v1384())
                return 4;
        if (pi_depth_v1381 ||
            pi_disable_count_v1381 != pi_restore_count_v1381)
                return 5;
        return 0;
}

static int
test_refused_packed_free_v1839(unsigned int foreign)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *u = (kword_t *)(unsigned long)UAREA;
        int rc;

        fault_kind_v1395 = 0U;
        fault_calls_v1395 = 0U;
        reset_prefix_v1384();
        if (proc_pure_ram_drop_v1381(SLOT) != MM_OK)
                return 1;
        PROC_SET_TRANSITION(p);
        refuse_packed_free_v1839 = foreign ? 0U : 1U;
        foreign_packed_free_v1839 = foreign ? 1U : 0U;
        rc = proc_pure_ram_restore_v1391(SLOT, accept_payload_v1395);
        if (rc != MM_ERR_BUSY || refuse_packed_free_v1839 ||
            foreign_packed_free_v1839 || !PROC_TRANSITION(p) ||
            VM_PDP6_BASE(p) || u[PROC_SWAP_BACKING_OFFSET] != BACKING ||
            proc_storage_expect_v30(SLOT, PROC_STORAGE_PACKED) != 0 ||
            !check_suffix_v1384())
                return 2;
        if (foreign) {
                /* A wrong-owner suffix is not a deleted suffix. Never
                 * publish the destination or destructively roll it back.
                 */
                if (mm_extent_count != 2 ||
                    MM_EXTENT_BASE(&mm_extents[0]) != SOURCE + OMIT ||
                    MM_EXTENT_TYPE(&mm_extents[0]) !=
                        MM_TYPE_PACKED_PROCESS ||
                    MM_EXTENT_OWNER(&mm_extents[0]) != SLOT + 1U ||
                    MM_EXTENT_PINNED(&mm_extents[0]) ||
                    MM_EXTENT_BASE(&mm_extents[1]) != RESTORE ||
                    MM_EXTENT_TYPE(&mm_extents[1]) != MM_TYPE_PROCESS ||
                    MM_EXTENT_OWNER(&mm_extents[1]) != SLOT ||
                    MM_EXTENT_PINNED(&mm_extents[1]))
                        return 3;
        } else if (mm_extent_count != 1 ||
            MM_EXTENT_BASE(&mm_extents[0]) != SOURCE + OMIT ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PACKED_PROCESS ||
            MM_EXTENT_OWNER(&mm_extents[0]) != SLOT ||
            MM_EXTENT_PINNED(&mm_extents[0])) {
                /* Exact live source: only the temporary APR rolls back. */
                return 4;
        }
        if (pi_depth_v1381 ||
            pi_disable_count_v1381 != pi_restore_count_v1381)
                return 5;
        return 0;
}

int
main(void)
{
        int rc;

        rc = baseline_main_v1839();
        if (rc)
                return 01000 + rc;
        rc = test_lost_packed_free_v1839();
        if (rc)
                return 03000 + rc;
        rc = test_refused_packed_free_v1839(0U);
        if (rc)
                return 04000 + rc;
        rc = test_refused_packed_free_v1839(1U);
        if (rc)
                return 05000 + rc;
        return 0;
}
