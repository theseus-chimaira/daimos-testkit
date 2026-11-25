/* Source-linked, real KCC PDP-6 PURE MRES service transactions.
 * Appended after the existing v1384 MM/PROC/PI fixture, with that
 * fixture's standalone main suppressed by the v1395 test macro.
 * Only the VFS loader and MM compaction demand are test-controlled.
 */
extern int proc_pure_mres_reclaim_v1611(kword_t, kword_t, unsigned int);
#ifdef DAIMOS_TEST_PURE_SERVICE_V1612
/* v1902 original KCORE passes an explicit tagged AC1 request only
 * for the already-marked slot-0 recovery; ordinary request==0 is
 * still selected from the original proc_sched_cursor. */
extern int proc_pure_mres_service_v1611(kword_t);
#define PURE_TEST_SERVICE_CALL_V1902() proc_pure_mres_service_v1611(0UL)
/* Older standalone v1612 KCC guests do not link the entire original
 * idle-finalizer KCORE. Only the accepted v1902 integrated native
 * fixture must execute the real arm/backoff assembly. */
static unsigned int pure_test_recover_arm_calls_v1902;
int
proc_pure_recover_arm_v1902(kword_t uarea)
{
        if (uarea != UAREA)
                return -1;
        ++pure_test_recover_arm_calls_v1902;
        return 0;
}
#else
extern int proc_pure_mres_service_v1611(void);
#define PURE_TEST_SERVICE_CALL_V1902() proc_pure_mres_service_v1611()
#endif

unsigned int proc_high_slot = SLOTS;
kword_t proc_sched_cursor;
kword_t proc_swap_pressure_ticks;
static unsigned int compact_calls_v1611;
static unsigned int prefix_calls_v1611;
static unsigned int full_calls_v1611;
static unsigned int prefix_fallback_v1611;
static unsigned int full_refuse_v1611;
#ifdef DAIMOS_TEST_PURE_SERVICE_V1612
static unsigned int compact_refuse_at_v1916;
static int compact_refuse_rc_v1916;
static unsigned int full_fault_v1917;
#endif

int
mm_is_pinned(kword_t base)
{
        int i = find_extent(base);
        if (i < 0)
                return 1;
        return MM_EXTENT_PINNED(&mm_extents[i]) != 0UL;
}

int
mm_compact(kword_t words, kword_t alignment)
{
        ++compact_calls_v1611;
#ifdef DAIMOS_TEST_PURE_SERVICE_V1612
        if (compact_calls_v1611 == compact_refuse_at_v1916)
                return compact_refuse_rc_v1916;
#endif
        if (words != 0200UL || alignment != 02000UL)
                return MM_ERR_INVAL;
        if (mm_extent_count == 1 &&
            MM_EXTENT_TYPE(&mm_extents[0]) == MM_TYPE_PACKED_PROCESS)
                return MM_OK;
        return MM_ERR_FRAGMENTED;
}

int
exec_image_prefix_backing_v1386(kword_t backing, kword_t base,
    kword_t uarea, kword_t prefix)
{
        ++prefix_calls_v1611;
        if (prefix_fallback_v1611)
                return -2;
        return prefix_plain_v1384(backing, base, uarea, prefix);
}

int
exec_image_full_bounded_v1391(kword_t backing, kword_t base,
    kword_t uarea, kword_t capacity)
{
        kword_t *data = (kword_t *)(unsigned long)base;
        unsigned int i;
        ++full_calls_v1611;
#ifdef DAIMOS_TEST_PURE_SERVICE_V1612
        if (full_fault_v1917) {
                int src = find_extent(SOURCE + OMIT);
                int dst = find_extent(base);
                if (src < 0 || dst < 0)
                        return -1;
                if (full_fault_v1917 == 1U) {
                        /* Foreign claim before deferred arm; the RAW
                         * source has already lost its transaction pin. */
                        mm_extents[dst].meta =
                            (mm_extents[dst].meta & ~MM_OWNER_MASK) |
                            (SLOT + 1U);
                        (void)mm_unpin(SOURCE + OMIT);
                } else if (full_fault_v1917 == 2U) {
                        mm_extents[src].meta =
                            (mm_extents[src].meta & ~MM_OWNER_MASK) |
                            (SLOT + 1U);
                } else {
                        (void)mm_pin(base);
                }
                return -1;
        }
#endif
        if (full_refuse_v1611 || backing != BACKING ||
            base != RESTORE || uarea != UAREA || capacity != WORDS)
                return -1;
        for (i = 020U; i < WORDS; ++i)
                data[i] = i < OMIT ? TEXT_PATTERN : 077777UL;
        return 0;
}

static void
reset_service_v1611(void)
{
        reset_prefix_v1384();
#ifdef DAIMOS_TEST_PURE_SERVICE_V1612
        mm_extent_capacity = MM_MAX_EXTENTS;
        pure_test_recover_arm_calls_v1902 = 0U;
        compact_refuse_at_v1916 = 0U;
        compact_refuse_rc_v1916 = 0;
        full_fault_v1917 = 0U;
#endif
        /* Direct v1384 component fixtures begin with ownership already
         * claimed. The actual MRES must claim TRANSITION itself. */
        PROC_CLEAR_TRANSITION(&process_slots[SLOT]);
        backstore_enabled = 0U;
        backstore_blocks = 0UL;
        backstore_blocks_used = 0UL;
        backstore_bitmap = (kword_t *)0;
        proc_swap_blocks_used = 0UL;
        proc_current_slot = 0UL;
        proc_sched_cursor = 0UL;
        proc_swap_pressure_ticks = 0UL;
        compact_calls_v1611 = 0U;
        prefix_calls_v1611 = 0U;
        full_calls_v1611 = 0U;
        prefix_fallback_v1611 = 0U;
        full_refuse_v1611 = 0U;
}

static int
check_retained_v1611(void)
{
        struct proc *p = &process_slots[SLOT];
        return !VM_PDP6_BASE(p) && !PROC_TRANSITION(p) &&
            mm_extent_count == 1 &&
            MM_EXTENT_BASE(&mm_extents[0]) == SOURCE + OMIT &&
            MM_EXTENT_WORDS(&mm_extents[0]) == SUFFIX &&
            MM_EXTENT_TYPE(&mm_extents[0]) == MM_TYPE_PACKED_PROCESS &&
            !MM_EXTENT_PINNED(&mm_extents[0]) &&
            proc_storage_expect_v30(SLOT, PROC_STORAGE_PACKED) == 0 &&
            ((kword_t *)(unsigned long)UAREA)[PROC_SWAP_BACKING_OFFSET] ==
                BACKING &&
            swap_slots[SLOT].state == BACKING &&
            check_suffix_v1384();
}

#ifdef DAIMOS_TEST_PURE_SERVICE_V1612
static int
test_reclaim_geometry_v1922(void)
{
        struct proc *p = &process_slots[SLOT];
        reset_service_v1611();
        mm_arena_count = MM_MAX_ARENAS + 1;
        if (proc_pure_mres_reclaim_v1611(0200UL, 02000UL, 0U) != MM_ERR_INVAL ||
            compact_calls_v1611 || PROC_TRANSITION(p) || mm_extent_count != 1)
                return 1;
        mm_extent_count = 0;
        if (proc_pure_mres_reclaim_v1611(0200UL, 02000UL, 0U) != MM_ERR_INVAL ||
            compact_calls_v1611 || pi_depth_v1381 ||
            pi_disable_count_v1381 != pi_restore_count_v1381)
                return 2;
        return 0;
}
#endif

static int
test_drop_wake_v1611(unsigned int fallback)
{
        struct proc *p = &process_slots[SLOT];
        int rc;

        reset_service_v1611();
        if (proc_pure_mres_reclaim_v1611(0200UL, 02000UL, 0U) != 0 ||
            !check_retained_v1611() || compact_calls_v1611 != 2U)
                return 1;
        PROC_SET_STATE(p, PROC_SRUN);
        proc_sched_cursor = PROC_SCHED_SWAP_REQUEST | SLOT;
        prefix_fallback_v1611 = fallback;
        rc = PURE_TEST_SERVICE_CALL_V1902();
        if (rc != (int)(01000U | SLOT) ||
            proc_sched_cursor != (01000UL | SLOT) ||
            proc_swap_pressure_ticks ||
            PROC_TRANSITION(p) || mm_extent_count != 1 ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PROCESS ||
            proc_storage_expect_v30(SLOT, PROC_STORAGE_RESIDENT) != 0 ||
            VM_PDP6_BASE(p) != (fallback ? RESTORE : SOURCE) ||
            prefix_calls_v1611 != 1U ||
            full_calls_v1611 != fallback ||
            !check_suffix_v1384())
                return 2;
        return 0;
}

static int
test_refusal_v1611(void)
{
        struct proc *p = &process_slots[SLOT];
        vnode_t *roots;
        int rc;

        reset_service_v1611();
        backstore_blocks = 0200UL;
        if (proc_pure_mres_reclaim_v1611(0200UL, 02000UL, 0U) != -1 ||
            PROC_TRANSITION(p) || VM_PDP6_BASE(p) != SOURCE ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PROCESS)
                return 1;
        backstore_blocks = 0UL;
        roots = vfs_mount_root_base;
        vfs_mount_root_base = (vnode_t *)0;
        if (proc_pure_mres_reclaim_v1611(0200UL, 02000UL, 0U) != -1 ||
            PROC_TRANSITION(p) || VM_PDP6_BASE(p) != SOURCE ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PROCESS)
                return 2;
        vfs_mount_root_base = roots;
        if (proc_pure_mres_reclaim_v1611(0200UL, 02000UL, 0U) != 0 ||
            !check_retained_v1611())
                return 3;
        PROC_SET_STATE(p, PROC_SRUN);
        proc_sched_cursor = PROC_SCHED_SWAP_REQUEST | SLOT;
        vfs_mount_root_base = (vnode_t *)0;
        rc = PURE_TEST_SERVICE_CALL_V1902();
        vfs_mount_root_base = roots;
        if (rc != 0 || proc_sched_cursor != SLOT ||
            proc_swap_pressure_ticks != 0100UL ||
            !check_retained_v1611() || full_calls_v1611 ||
            prefix_calls_v1611)
                return 4;

        proc_swap_pressure_ticks = 0UL;
        proc_sched_cursor = PROC_SCHED_SWAP_REQUEST | SLOT;
        prefix_fallback_v1611 = 1U;
        full_refuse_v1611 = 1U;
        rc = PURE_TEST_SERVICE_CALL_V1902();
        if (rc != 0 || proc_sched_cursor != SLOT ||
            proc_swap_pressure_ticks != 0100UL ||
            !check_retained_v1611() ||
            prefix_calls_v1611 != 1U || full_calls_v1611 != 1U)
                return 5;
        return 0;
}

#ifdef DAIMOS_TEST_PURE_SERVICE_V1612
/*
 * The v1612 policy has one MM-owner scan for both resident and PACKED.
 * A second physical owner of the same process is never safe to unlock.
 * Deliberately construct a corrupt duplicate and insist that both
 * READY_ONCE and TRANSITION-release fail closed.
 */
static int
test_duplicate_packed_owner_v1612(void)
{
        struct proc *p = &process_slots[SLOT];
        int rc;

        reset_service_v1611();
        if (proc_pure_mres_reclaim_v1611(0200UL, 02000UL, 0U) != 0 ||
            !check_retained_v1611())
                return 1;
        mm_extents[1].span = ((kword_t)02000UL << 18U) | RESTORE;
        mm_extents[1].meta = ((kword_t)MM_TYPE_PROCESS << MM_TYPE_SHIFT) |
            (kword_t)SLOT;
        mm_extent_count = 2;
        PROC_SET_STATE(p, PROC_SRUN);
        proc_sched_cursor = PROC_SCHED_SWAP_REQUEST | SLOT;
        rc = PURE_TEST_SERVICE_CALL_V1902();
        if (rc || proc_sched_cursor != SLOT ||
            proc_swap_pressure_ticks != 0100UL ||
            !PROC_TRANSITION(p) || VM_PDP6_BASE(p) ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PACKED_PROCESS ||
            MM_EXTENT_WORDS(&mm_extents[0]) != SUFFIX ||
            mm_extent_count != 2)
                return 2;
        return 0;
}

static int
test_pinned_packed_owner_v1612(void)
{
        struct proc *p = &process_slots[SLOT];
        int rc;

        reset_service_v1611();
        if (proc_pure_mres_reclaim_v1611(0200UL, 02000UL, 0U) != 0 ||
            !check_retained_v1611())
                return 1;
        if (mm_pin(SOURCE + OMIT) != MM_OK)
                return 2;
        PROC_SET_STATE(p, PROC_SRUN);
        proc_sched_cursor = PROC_SCHED_SWAP_REQUEST | SLOT;
        rc = PURE_TEST_SERVICE_CALL_V1902();
        if (rc || proc_sched_cursor != SLOT ||
            !PROC_TRANSITION(p) || VM_PDP6_BASE(p) ||
            MM_EXTENT_PINS(&mm_extents[0]) != 1U)
                return 3;
        return 0;
}

/* A hard compactor refusal is not ordinary memory pressure.
 * Test both before DROP and after an already committed DROP.
 */
static int
test_compact_refusal_v1916(int refusal, unsigned int at)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *u = (kword_t *)(unsigned long)UAREA;

        reset_service_v1611();
        compact_refuse_at_v1916 = at;
        compact_refuse_rc_v1916 = refusal;
        if (proc_pure_mres_reclaim_v1611(0200UL, 02000UL, 0U) !=
            refusal || compact_calls_v1611 != at ||
            prefix_calls_v1611 || full_calls_v1611)
                return 1;
        if (at == 2U)
                return check_retained_v1611() ? 0 : 2;
        if (PROC_TRANSITION(p) || VM_PDP6_BASE(p) != SOURCE ||
            proc_storage_expect_v30(SLOT, PROC_STORAGE_RESIDENT) != 0 ||
            mm_extent_count != 1 ||
            MM_EXTENT_BASE(&mm_extents[0]) != SOURCE ||
            MM_EXTENT_WORDS(&mm_extents[0]) != WORDS ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PROCESS ||
            MM_EXTENT_OWNER(&mm_extents[0]) != SLOT ||
            MM_EXTENT_PINNED(&mm_extents[0]) ||
            u[PROC_SWAP_BACKING_OFFSET] ||
            swap_slots[SLOT].state != BACKING || !check_suffix_v1384())
                return 3;
        return 0;
}

/* A DROP with unprovable original geometry must not be converted
 * to ordinary no-victim pressure. The bad descriptor stays untouched.
 */
static int
test_uncertain_drop_v1916(void)
{
        struct proc *p = &process_slots[SLOT];
        kword_t span, meta;

        reset_service_v1611();
        mm_extents[0].span = ((WORDS - 0200UL) << 18U) | SOURCE;
        span = mm_extents[0].span;
        meta = mm_extents[0].meta;
        if (proc_pure_mres_reclaim_v1611(0200UL, 02000UL, 0U) !=
            MM_ERR_INVAL || compact_calls_v1611 != 1U ||
            !PROC_TRANSITION(p) || VM_PDP6_BASE(p) != SOURCE ||
            proc_storage_expect_v30(SLOT, PROC_STORAGE_RESIDENT) != 0 ||
            mm_extent_count != 1 || mm_extents[0].span != span ||
            mm_extents[0].meta != meta || !check_suffix_v1384())
                return 1;
        return 0;
}

static int
test_full_cancel_v1917(unsigned int kind)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *u = (kword_t *)(unsigned long)UAREA;
        int src, dst;

        reset_service_v1611();
        if (proc_pure_mres_reclaim_v1611(0200UL, 02000UL, 0U) ||
            !check_retained_v1611())
                return 1;
        PROC_SET_STATE(p, PROC_SRUN);
        proc_sched_cursor = PROC_SCHED_SWAP_REQUEST | SLOT;
        prefix_fallback_v1611 = 1U;
        full_fault_v1917 = kind;
        if (PURE_TEST_SERVICE_CALL_V1902() || !PROC_TRANSITION(p) ||
            VM_PDP6_BASE(p) || proc_sched_cursor != SLOT ||
            mm_extent_count != 2 || free_count_v1381 ||
            u[PROC_FINALIZE_OFFSET] !=
                PROC_PURE_FULL_ESCROW_V1917(SOURCE + OMIT, RESTORE) ||
            pure_test_recover_arm_calls_v1902 != 1U ||
            !check_suffix_v1384())
                return 2;
        src = find_extent(SOURCE + OMIT);
        dst = find_extent(RESTORE);
        if (src < 0 || dst < 0 ||
            MM_EXTENT_OWNER(&mm_extents[src]) !=
                (kind == 2U ? SLOT + 1U : SLOT) ||
            MM_EXTENT_OWNER(&mm_extents[dst]) !=
                (kind == 1U ? SLOT + 1U : SLOT) ||
            MM_EXTENT_PINS(&mm_extents[src]) != (kind == 1U ? 0U : 1U) ||
            MM_EXTENT_PINS(&mm_extents[dst]) != (kind == 3U ? 2U : 1U) ||
            pi_depth_v1381 || pi_disable_count_v1381 != pi_restore_count_v1381)
                return 3;
        if (proc_pure_mres_service_v1611(0400000UL | SLOT) != -1 ||
            !PROC_TRANSITION(p) || free_count_v1381 ||
            mm_extent_count != 2)
                return 4;
        return 0;
}

static int
test_retry_overlap_v1917(void)
{
        struct proc *p = &process_slots[SLOT];
        vnode_t *roots;

        reset_service_v1611();
        if (proc_pure_mres_reclaim_v1611(0200UL, 02000UL, 0U) ||
            !check_retained_v1611())
                return 1;
        add_extent(SOURCE + OMIT + 0200UL, 0200UL, MM_TYPE_PROCESS);
        mm_extents[1].meta =
            (mm_extents[1].meta & ~MM_OWNER_MASK) | (SLOT + 1U);
        PROC_SET_STATE(p, PROC_SRUN);
        proc_sched_cursor = PROC_SCHED_SWAP_REQUEST | SLOT;
        roots = vfs_mount_root_base;
        vfs_mount_root_base = (vnode_t *)0;
        (void)PURE_TEST_SERVICE_CALL_V1902();
        vfs_mount_root_base = roots;
        if (!PROC_TRANSITION(p) || VM_PDP6_BASE(p) ||
            mm_extent_count != 2 || free_count_v1381 ||
            !check_suffix_v1384())
                return 2;
        return 0;
}
#endif

int
main(void)
{
        int rc;
#ifdef DAIMOS_TEST_PURE_SERVICE_V1612
        rc = test_reclaim_geometry_v1922();
        if (rc)
                return 06000 + rc;
#endif

        rc = test_drop_wake_v1611(0U);
        if (rc)
                return 0100 + rc;
        rc = test_drop_wake_v1611(1U);
        if (rc)
                return 0200 + rc;
        rc = test_refusal_v1611();
        if (rc)
                return 0300 + rc;
#ifdef DAIMOS_TEST_PURE_SERVICE_V1612
        rc = test_duplicate_packed_owner_v1612();
        if (rc)
                return 0400 + rc;
        rc = test_pinned_packed_owner_v1612();
        if (rc)
                return 0500 + rc;
        rc = test_compact_refusal_v1916(MM_ERR_INVAL, 1U);
        if (rc)
                return 0600 + rc;
        rc = test_compact_refusal_v1916(MM_ERR_BUSY, 1U);
        if (rc)
                return 0700 + rc;
        rc = test_compact_refusal_v1916(MM_ERR_INVAL, 2U);
        if (rc)
                return 01000 + rc;
        rc = test_compact_refusal_v1916(MM_ERR_BUSY, 2U);
        if (rc)
                return 01100 + rc;
        rc = test_uncertain_drop_v1916();
        if (rc)
                return 01200 + rc;
        rc = test_full_cancel_v1917(1U);
        if (rc)
                return 01300 + rc;
        rc = test_full_cancel_v1917(2U);
        if (rc)
                return 01400 + rc;
        rc = test_full_cancel_v1917(3U);
        if (rc)
                return 01500 + rc;
        rc = test_retry_overlap_v1917();
        if (rc)
                return 01600 + rc;
#endif
        return 0;
}
