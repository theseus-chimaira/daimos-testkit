/* Source-linked, real KCC PDP-6 PURE MRES service transactions.
 * Appended after the existing v1384 MM/PROC/PI fixture, with that
 * fixture's standalone main suppressed by the v1395 test macro.
 * Only the VFS loader and MM compaction demand are test-controlled.
 */
extern int proc_pure_mres_reclaim_v1611(kword_t, kword_t, unsigned int);
extern int proc_pure_mres_service_v1611(void);

unsigned int proc_high_slot = SLOTS;
kword_t proc_sched_cursor;
kword_t proc_swap_pressure_ticks;
static unsigned int compact_calls_v1611;
static unsigned int prefix_calls_v1611;
static unsigned int full_calls_v1611;
static unsigned int prefix_fallback_v1611;
static unsigned int full_refuse_v1611;

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
        rc = proc_pure_mres_service_v1611();
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
        rc = proc_pure_mres_service_v1611();
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
        rc = proc_pure_mres_service_v1611();
        if (rc != 0 || proc_sched_cursor != SLOT ||
            proc_swap_pressure_ticks != 0100UL ||
            !check_retained_v1611() ||
            prefix_calls_v1611 != 1U || full_calls_v1611 != 1U)
                return 5;
        return 0;
}

int
main(void)
{
        int rc;

        rc = test_drop_wake_v1611(0U);
        if (rc)
                return 0100 + rc;
        rc = test_drop_wake_v1611(1U);
        if (rc)
                return 0200 + rc;
        rc = test_refusal_v1611();
        if (rc)
                return 0300 + rc;
        return 0;
}
