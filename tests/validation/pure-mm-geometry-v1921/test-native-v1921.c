/* Source-linked FULL commit and common sorted-table geometry gate. */
extern int proc_pure_full_owners_v1917(unsigned int, kword_t, kword_t,
    kword_t, kword_t, unsigned int, unsigned int);
extern kword_t proc_pure_owner_v1918(unsigned int, unsigned int,
    kword_t, kword_t, unsigned int);
static unsigned int fault_v1921, load_calls_v1921, free_calls_v1921;

int
pin_v1921(kword_t base)
{
        if ((fault_v1921 == 1U && base == SOURCE + OMIT) ||
            (fault_v1921 == 2U && base == RESTORE))
                return MM_OK; /* false success, no original pin */
        return mm_pin(base);
}

int
unpin_v1921(kword_t base)
{
        int rc = mm_unpin(base);
        if (rc == MM_OK && fault_v1921 == 3U && base == RESTORE)
                mm_extents[0].meta = (mm_extents[0].meta & ~MM_OWNER_MASK) |
                    (SLOT + 1U);
        if (rc == MM_OK && fault_v1921 == 4U && base == RESTORE)
                mm_extents[1].meta = (mm_extents[1].meta & ~MM_OWNER_MASK) |
                    (SLOT + 1U);
        return rc;
}

int
free_v1921(kword_t base, unsigned int type, unsigned int owner)
{
        ++free_calls_v1921;
        if (base == SOURCE + OMIT && fault_v1921 == 5U)
                return MM_OK; /* original authoritative suffix survives */
        if (base == SOURCE + OMIT && fault_v1921 == 6U) {
                mm_extents[0].meta = (mm_extents[0].meta & ~MM_OWNER_MASK) |
                    (SLOT + 1U);
                return MM_OK;
        }
        return mm_free(base, type, owner);
}

static int
load_v1921(kword_t backing, kword_t base, kword_t stable, kword_t capacity)
{
        ++load_calls_v1921;
        if (fault_v1921 == 4U)
                return -1; /* force rollback */
        return accept_payload_v1395(backing, base, stable, capacity);
}

static int
full_v1921(unsigned int kind)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *u = (kword_t *)(unsigned long)UAREA;
        kword_t *dest = (kword_t *)(unsigned long)RESTORE;
        unsigned int i;
        fault_v1921 = 0U;
        reset_prefix_v1384();
        if (proc_pure_ram_drop_v1381(SLOT) != MM_OK)
                return 1;
        PROC_SET_TRANSITION(p);
        for (i = 0U; i < WORDS; ++i)
                dest[i] = 012345UL;
        load_calls_v1921 = free_calls_v1921 = 0U;
        fault_v1921 = kind;
        if (proc_pure_ram_restore_v1391(SLOT, load_v1921) != MM_ERR_BUSY ||
            !PROC_TRANSITION(p) || VM_PDP6_BASE(p) ||
            u[PROC_SWAP_BACKING_OFFSET] != BACKING ||
            proc_storage_expect_v30(SLOT, PROC_STORAGE_PACKED) ||
            !check_suffix_v1384() || pi_depth_v1381 ||
            pi_disable_count_v1381 != pi_restore_count_v1381)
                return 2;
        if (kind <= 2U) {
                if (load_calls_v1921 || free_calls_v1921 ||
                    alloc_count_v1381 != (kind == 1U ? 0U : 1U))
                        return 3;
                for (i = 0U; i < WORDS; ++i)
                        if (dest[i] != 012345UL)
                                return 4;
        } else if (load_calls_v1921 != 1U)
                return 5;
        if (kind == 3U && (MM_EXTENT_OWNER(&mm_extents[0]) != SLOT + 1U ||
            MM_EXTENT_PINS(&mm_extents[0]) != 1U))
                return 8;
        if (kind == 4U && (MM_EXTENT_OWNER(&mm_extents[1]) != SLOT + 1U ||
            MM_EXTENT_PINS(&mm_extents[0]) != 1U))
                return 9;
        if (kind == 5U) {
                if (mm_extent_count != 1 || free_calls_v1921 != 2U ||
                    u[PROC_FINALIZE_OFFSET] || MM_EXTENT_PINS(&mm_extents[0]))
                        return 6;
        } else if (mm_extent_count != (kind == 1U ? 1 : 2) ||
            free_calls_v1921 != (kind == 6U ? 1U : 0U) ||
            u[PROC_FINALIZE_OFFSET] != PROC_PURE_FULL_ESCROW_V1917(
                SOURCE + OMIT, kind == 1U ? 0UL : RESTORE))
                return 7;
        return 0;
}

/* Foreign ordering/overlap away from the transaction is still invalid:
 * the native allocator and prefix claim use the sorted-table invariant. */
static int
geometry_v1921(unsigned int kind)
{
        kword_t pi;
        int full;
        kword_t sole;
        reset_prefix_v1384();
        if (proc_pure_ram_drop_v1381(SLOT) != MM_OK)
                return 1;
        add_extent(070000UL, 0200UL, MM_TYPE_MODULE);
        add_extent(070200UL, 0200UL, MM_TYPE_KERNEL_DYNAMIC);
        if (kind == 1U)
                mm_extents[2].span = (0200UL << 18U) | 067000UL;
        if (kind == 2U)
                mm_extents[2].span = (0200UL << 18U) | 070100UL;
        if (kind == 3U)
                mm_extents[2].span = (0200UL << 18U) | 0777700UL;
        if (kind == 4U)
                mm_extent_capacity = 2U;
        pi = mach_pi_disable();
        sole = proc_pure_owner_v1918(SLOT, MM_TYPE_PACKED_PROCESS,
            0UL, SUFFIX, 0U);
        full = proc_pure_full_owners_v1917(SLOT, SOURCE + OMIT, SUFFIX,
            0UL, WORDS, 0U, 0U);
        mach_pi_restore(pi);
        if (sole != (kind ? 0UL : SOURCE + OMIT) ||
            full != (kind ? -1 : 1))
                return 2;
        return 0;
}

int
main(void)
{
        unsigned int kind;
        int rc;
        for (kind = 1U; kind <= 6U; ++kind) {
                rc = full_v1921(kind);
                if (rc)
                        return (int)(kind * 0100U) + rc;
        }
        for (kind = 0U; kind <= 4U; ++kind) {
                rc = geometry_v1921(kind);
                if (rc)
                        return (int)(01000U + kind * 010U) + rc;
        }
        return 0;
}
