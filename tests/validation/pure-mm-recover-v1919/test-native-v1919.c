/* Native v1919: deferred DROP/PREFIX rollback through the real MRES. */
#define RECOVER_V1919() proc_pure_mres_service_v1611(0400000UL | SLOT)
#define DROP_ESCROW_V1919 PROC_PURE_INPLACE_ESCROW_V1919(SOURCE + OMIT, PROC_PURE_DROP_TAG_V1919)
#define PREFIX_ESCROW_V1919 PROC_PURE_INPLACE_ESCROW_V1919(SOURCE + OMIT, PROC_PURE_PREFIX_TAG_V1919)

static unsigned int fault_v1919, pins_v1919, unpins_v1919;
static unsigned int rebases_v1919, releases_v1919;

int
rebase_fault_v1919(kword_t base, unsigned int owner, kword_t prefix,
    kword_t words)
{
        int rc;
        ++rebases_v1919;
        if (fault_v1919 == 2U)
                return MM_ERR_BUSY;
        rc = mm_pure_rebase_pinned_v1381(base, owner, prefix, words);
        if (rc == MM_OK && fault_v1919 == 3U) {
                /* Rebase committed, but its pin was retired before the
                 * reply could be reconciled. Mode is still RESIDENT. */
                (void)mm_unpin(base + prefix);
                return MM_ERR_BUSY;
        }
        return rc;
}

int
pin_fault_v1919(kword_t base)
{
        int rc;
        ++pins_v1919;
        if (fault_v1919 == 9U)
                return MM_ERR_BUSY;
        rc = mm_pin(base);
        return rc == MM_OK && fault_v1919 == 10U ? MM_ERR_BUSY : rc;
}

int
unpin_fault_v1919(kword_t base)
{
        int rc;
        ++unpins_v1919;
        if (fault_v1919 == 1U || fault_v1919 == 2U)
                return MM_ERR_BUSY;
        rc = mm_unpin(base);
        return rc == MM_OK && fault_v1919 == 8U ? MM_ERR_BUSY : rc;
}

int
release_fault_v1919(kword_t base, unsigned int owner, kword_t prefix,
    kword_t words)
{
        int rc;
        ++releases_v1919;
        if (fault_v1919 == 4U)
                return MM_ERR_BUSY;
        rc = mm_pure_release_prefix_v1384(base, owner, prefix, words);
        if (rc == MM_OK && fault_v1919 == 6U)
                mm_extents[0].meta =
                    (mm_extents[0].meta & ~MM_OWNER_MASK) | (SLOT + 1U);
        return rc == MM_OK && fault_v1919 == 8U ? MM_ERR_BUSY : rc;
}

int
commit_fault_v1919(kword_t base, unsigned int owner, kword_t prefix,
    kword_t words)
{
        int rc = mm_pure_commit_prefix_v1384(base, owner, prefix, words);
        if (rc == MM_OK && fault_v1919 == 5U) {
                (void)mm_pin(base);
                return MM_ERR_BUSY;
        }
        return rc;
}

int
prefix_fault_v1919(kword_t backing, kword_t base, kword_t uarea,
    kword_t prefix)
{
        int rc = exec_image_prefix_backing_v1386(backing, base, uarea, prefix);
        if (rc == 0 && fault_v1919 == 7U)
                (void)mm_pin(base);
        if (fault_v1919 == 4U || fault_v1919 == 6U)
                return -1;
        return rc;
}

static void
reset_v1919(void)
{
        reset_service_v1611();
        fault_v1919 = pins_v1919 = unpins_v1919 = 0U;
        rebases_v1919 = releases_v1919 = 0U;
}

/* Common invariants across a retry, regardless of owner shape. */
static int
stable_v1919(kword_t escrow, unsigned int held, kword_t cursor)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *u = (kword_t *)(unsigned long)UAREA;
        return PROC_UAREA_BASE(p) == UAREA &&
            (PROC_TRANSITION(p) != 0) == held &&
            u[PROC_FINALIZE_OFFSET] == escrow &&
            u[PROC_FDCTL_OFFSET] == 0UL && u[020U] == 01234567UL &&
            swap_slots[SLOT].state == BACKING &&
            proc_sched_cursor == cursor && mm_extent_count == 1 &&
            !alloc_count_v1381 && !free_count_v1381 &&
            !pi_depth_v1381 && pi_disable_count_v1381 == pi_restore_count_v1381 &&
            check_suffix_v1384();
}

static int
test_drop_v1919(unsigned int kind)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *u = (kword_t *)(unsigned long)UAREA;
        unsigned int calls;
        kword_t base;

        reset_v1919();
        u[020U] = 01234567UL;
        proc_current_slot = SLOT + 1U;
        proc_sched_cursor = SLOT + 1U;
        fault_v1919 = kind;
        if (proc_pure_mres_reclaim_v1611(0200UL, 02000UL, SLOT + 1U) !=
            MM_ERR_BUSY || pure_test_recover_arm_calls_v1902 != 1U ||
            compact_calls_v1611 != 1U ||
            !stable_v1919(DROP_ESCROW_V1919, 1U, SLOT + 1U))
                return 1;
        if (VM_PDP6_BASE(p) != (kind == 1U ? 0UL : SOURCE))
                return 2;
        calls = unpins_v1919;
        if (RECOVER_V1919() != -1 || unpins_v1919 != calls)
                return 3;
        proc_current_slot = 0UL;
        base = kind == 2U ? SOURCE : SOURCE + OMIT;
        if (kind != 3U) {
                if (RECOVER_V1919() != -1 || unpins_v1919 != calls ||
                    MM_EXTENT_PINS(&mm_extents[0]) != 1U ||
                    !stable_v1919(DROP_ESCROW_V1919, 1U, SLOT + 1U))
                        return 4;
                if (mm_unpin(base) != MM_OK)
                        return 5;
        }
        fault_v1919 = 0U;
        if (RECOVER_V1919() != 0 || !stable_v1919(0UL, 0U, SLOT + 1U) ||
            unpins_v1919 != calls || MM_EXTENT_BASE(&mm_extents[0]) != base)
                return 6;
        if (kind == 2U) {
                if (VM_PDP6_BASE(p) != SOURCE ||
                    MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PROCESS ||
                    MM_EXTENT_WORDS(&mm_extents[0]) != WORDS ||
                    u[PROC_SWAP_BACKING_OFFSET] ||
                    proc_storage_expect_v30(SLOT, PROC_STORAGE_RESIDENT))
                        return 7;
        } else if (!check_retained_v1611())
                return 8;
        return 0;
}

static int
test_prefix_v1919(unsigned int kind)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *u = (kword_t *)(unsigned long)UAREA;
        kword_t base;
        unsigned int calls, claims;

        reset_v1919();
        u[020U] = 01234567UL;
        if (proc_pure_mres_reclaim_v1611(0200UL, 02000UL, 0U) ||
            !check_retained_v1611())
                return 1;
        PROC_SET_STATE(p, PROC_SRUN);
        proc_sched_cursor = PROC_SCHED_SWAP_REQUEST | SLOT;
        fault_v1919 = kind;
        if (PURE_TEST_SERVICE_CALL_V1902() != 0 ||
            pure_test_recover_arm_calls_v1902 != 1U || full_calls_v1611 ||
            VM_PDP6_BASE(p) || !stable_v1919(PREFIX_ESCROW_V1919, 1U, SLOT))
                return 2;
        base = kind == 6U ? SOURCE + OMIT : SOURCE;
        calls = unpins_v1919;
        claims = pins_v1919;
        /* Even a sole pre-existing pin cannot be consumed by idle retry. */
        if (RECOVER_V1919() != -1 || unpins_v1919 != calls || pins_v1919 != claims)
                return 3;
        if (kind == 7U) {
                if (MM_EXTENT_PINS(&mm_extents[0]) != 2U ||
                    mm_unpin(base) != MM_OK || RECOVER_V1919() != -1 ||
                    unpins_v1919 != calls || pins_v1919 != claims)
                        return 4;
        }
        if (mm_unpin(base) != MM_OK)
                return 5;
        if (kind == 6U) {
                /* Foreign claim and same-slot replacement are distinct
                 * from the original escrow, even after pin retirement. */
                if (RECOVER_V1919() != -1 || unpins_v1919 != calls)
                        return 6;
                mm_extents[0].meta = (mm_extents[0].meta & ~MM_OWNER_MASK) | SLOT;
                mm_extents[0].span = (SUFFIX << 18U) | PACKED;
                if (RECOVER_V1919() != -1 || pins_v1919 != claims)
                        return 7;
                mm_extents[0].span = (SUFFIX << 18U) | (SOURCE + OMIT);
        }
        if (kind == 4U) {
                /* A refused new pin changes nothing. A refused release
                 * retires only its NEW pin and may retry a later tick. */
                fault_v1919 = 9U;
                if (RECOVER_V1919() != -1 || unpins_v1919 != calls ||
                    MM_EXTENT_PINS(&mm_extents[0]))
                        return 8;
                fault_v1919 = 4U;
                if (RECOVER_V1919() != -1 || unpins_v1919 != calls + 1U ||
                    MM_EXTENT_PINS(&mm_extents[0]) ||
                    MM_EXTENT_BASE(&mm_extents[0]) != SOURCE ||
                    !stable_v1919(PREFIX_ESCROW_V1919, 1U, SLOT))
                        return 9;
                ++calls;
        }
        /* Reconcile a newly acquired pin with lost reply (case 4),
         * or successful release/unpin with lost replies. */
        fault_v1919 = kind == 4U ? 10U : 8U;
        if (RECOVER_V1919() != 0 || !stable_v1919(0UL, 0U, SLOT) ||
            !check_retained_v1611() ||
            unpins_v1919 != calls + (kind == 6U ? 0U : 1U))
                return 10;
        fault_v1919 = 0U;
        proc_sched_cursor = PROC_SCHED_SWAP_REQUEST | SLOT;
        if (PURE_TEST_SERVICE_CALL_V1902() != (int)(01000U | SLOT) ||
            PROC_TRANSITION(p) || VM_PDP6_BASE(p) != SOURCE ||
            prefix_calls_v1611 != 2U || !check_suffix_v1384())
                return 11;
        return 0;
}

/* Invalid marker and shape combinations must not enter the new path. */
static int
test_marker_v1919(void)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *u = (kword_t *)(unsigned long)UAREA;
        unsigned int kind;
        kword_t escrow, span, meta;
        reset_v1919();
        u[020U] = 01234567UL;
        if (proc_pure_mres_reclaim_v1611(0200UL, 02000UL, 0U))
                return 1;
        PROC_SET_TRANSITION(p);
        if (mm_pin(SOURCE + OMIT) ||
            mm_pure_claim_prefix_v1384(SOURCE + OMIT, SLOT, OMIT, WORDS) ||
            mm_unpin(SOURCE))
                return 2;
        span = mm_extents[0].span;
        meta = mm_extents[0].meta;
        for (kind = 1U; kind <= 6U; ++kind) {
                switch (kind) {
                case 1U: escrow = PROC_PURE_FULL_ESCROW_V1917(SOURCE + OMIT, 0UL); break;
                case 2U: escrow = DROP_ESCROW_V1919; break;
                case 3U: escrow = PREFIX_ESCROW_V1919 | PROC_PURE_DROP_TAG_V1919; break;
                case 4U: escrow = PREFIX_ESCROW_V1919 | RESTORE; break;
                case 5U: escrow = PREFIX_ESCROW_V1919 | PROC_FINALIZE_PREVM; break;
                default: escrow = PROC_SWAP_RETRY_TAG_V1507 | 01234UL; break;
                }
                u[PROC_FINALIZE_OFFSET] = escrow;
                if (RECOVER_V1919() != -1 || !stable_v1919(escrow, 1U, 0UL) ||
                    !check_no_mutation_v1381(span, meta) ||
                    pins_v1919 != 1U || unpins_v1919 != 1U)
                        return (int)kind + 2;
        }
        return 0;
}

int
main(void)
{
        unsigned int kind;
        int rc;
        for (kind = 1U; kind <= 3U; ++kind) {
                rc = test_drop_v1919(kind);
                if (rc)
                        return (int)(kind * 0100U) + rc;
        }
        for (kind = 4U; kind <= 7U; ++kind) {
                rc = test_prefix_v1919(kind);
                if (rc)
                        return (int)(kind * 0100U) + rc;
        }
        rc = test_marker_v1919();
        return rc ? 01000 + rc : 0;
}
