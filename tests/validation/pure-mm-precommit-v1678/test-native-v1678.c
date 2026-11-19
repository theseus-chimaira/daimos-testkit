/* v1678: Real PDP-6 MM pin and rebase refusals on a second owner.
 * Source-linked production DROP/service are unchanged; only the MM
 * call arguments of the second process are fault-controlled.
 * This preflight is distinct from physical PI6 concurrency tests.
 */
static unsigned int pin_fault_v1678;
static unsigned int rebase_fault_v1678;
static unsigned int pin_hits_v1678;
static unsigned int rebase_hits_v1678;

int
mm_pin_fault_v1678(kword_t base)
{
        if (base == SOURCE2_V1677 && pin_fault_v1678) {
                ++pin_hits_v1678;
                /* Call the ORIGINAL MM with an invalid zero base;
                 * prove its rejection rather than forging a return. */
                return mm_pin(0UL);
        }
        return mm_pin(base);
}

int
mm_pure_rebase_fault_v1678(kword_t base, unsigned int slot,
    kword_t skip, kword_t words)
{
        if (slot == SLOT2_V1677 && rebase_fault_v1678) {
                ++rebase_hits_v1678;
                /* Wrong exact skip goes through original PDP-6 MM.
                 * This must refuse before touching a descriptor. */
                return mm_pure_rebase_pinned_v1381(base, slot,
                    skip + 1UL, words);
        }
        return mm_pure_rebase_pinned_v1381(base, slot, skip, words);
}

/* Extend only the existing source-loader fixture to a second u-area.
 * Production prefix restoration, MM placement and mode publication
 * remain untouched and are still the instructions under test. */
int
exec_image_prefix_backing_v1386(kword_t backing, kword_t base,
    kword_t uarea, kword_t prefix)
{
        kword_t *dest;
        unsigned int i;
        if (uarea == UAREA)
                return exec_image_prefix_fixture_v1611(backing, base,
                    uarea, prefix);
        if (backing != BACKING || base != SOURCE2_V1677 ||
            uarea != UAREA2_V1677 || prefix != OMIT || pi_depth_v1381)
                return -1;
        dest = (kword_t *)(unsigned long)base;
        for (i = 020U; i < OMIT; ++i)
                dest[i] = TEXT_PATTERN;
        return 0;
}

static void
setup_two_v1678(void)
{
        struct proc *q = &process_slots[SLOT2_V1677];
        kword_t *u = (kword_t *)(unsigned long)UAREA2_V1677;
        kword_t *s = (kword_t *)(unsigned long)SOURCE2_V1677;
        unsigned int i;

        reset_service_v1611();
        drop_fault_v1658 = 0U;
        fault_second_v1677 = 0U;
        pin_hits_v1678 = 0U;
        rebase_hits_v1678 = 0U;
        add_extent(SOURCE2_V1677, WORDS, MM_TYPE_PROCESS);
        mm_extents[1].meta =
            (mm_extents[1].meta & ~((kword_t)0777UL)) | SLOT2_V1677;
        mm_arenas[0] = ((kword_t)0100000UL << 18U) | 040000UL;
        for (i = 0U; i < WORDS; ++i)
                s[i] = i < OMIT ? TEXT_PATTERN : PATTERN + i;
        for (i = 0U; i < PROC_UAREA_WORDS; ++i)
                u[i] = 0UL;
        q->meta = (UAREA2_V1677 << PROC_HALF_SHIFT) |
            ((kword_t)PROC_F_UAREA << PROC_FLAGS_SHIFT);
        q->vm_state = (WORDS << PROC_HALF_SHIFT) | SOURCE2_V1677;
        q->sched = (kword_t)PROC_SLEEP << PROC_STATE_SHIFT;
        swap_slots[SLOT2_V1677].state = BACKING;
        proc_high_slot = SLOT2_V1677 + 1U;
}

static int
resident_two_v1678(void)
{
        struct proc *q = &process_slots[SLOT2_V1677];
        kword_t *u = (kword_t *)(unsigned long)UAREA2_V1677;
        unsigned int i;
        kword_t *s = (kword_t *)(unsigned long)SOURCE2_V1677;

        if (!check_owner_v1677(SLOT2_V1677, SOURCE2_V1677,
            WORDS, MM_TYPE_PROCESS, 0U) ||
            PROC_TRANSITION(q) || VM_PDP6_BASE(q) != SOURCE2_V1677 ||
            u[PROC_SWAP_BACKING_OFFSET] ||
            proc_storage_expect_v30(SLOT2_V1677,
                PROC_STORAGE_RESIDENT) ||
            pi_depth_v1381 ||
            pi_disable_count_v1381 != pi_restore_count_v1381)
                return 0;
        for (i = 0U; i < WORDS; ++i)
                if (s[i] != (i < OMIT ? TEXT_PATTERN : PATTERN + i))
                        return 0;
        return 1;
}

static int
case_precommit_v1678(unsigned int kind)
{
        struct proc *p = &process_slots[SLOT];
        struct proc *q = &process_slots[SLOT2_V1677];
        int rc;

        setup_two_v1678();
        pin_fault_v1678 = (kind == 1U);
        rebase_fault_v1678 = (kind == 2U);
        rc = proc_pure_mres_reclaim_v1611(0200UL, 02000UL, 0U);
        pin_fault_v1678 = 0U;
        rebase_fault_v1678 = 0U;
        if (rc != -1 ||
            pin_hits_v1678 != (kind == 1U ? 1U : 0U) ||
            rebase_hits_v1678 != (kind == 2U ? 1U : 0U) ||
            !check_owner_v1677(SLOT, SOURCE + OMIT, SUFFIX,
                MM_TYPE_PACKED_PROCESS, 0U) ||
            !resident_two_v1678() || PROC_TRANSITION(p) ||
            VM_PDP6_BASE(p))
                return 1;
        /* The healthy PACKED owner still restores through original
         * slot-0 service while the failed second owner remains
         * a byte-exact runnable RESIDENT image, with no leaked pin. */
        PROC_SET_STATE(p, PROC_SRUN);
        proc_sched_cursor = PROC_SCHED_SWAP_REQUEST | SLOT;
        rc = proc_pure_mres_service_v1611();
        if (rc != (int)(01000UL | SLOT) ||
            proc_sched_cursor != (01000UL | SLOT) ||
            PROC_TRANSITION(p) || VM_PDP6_BASE(p) != SOURCE ||
            !check_owner_v1677(SLOT, SOURCE, WORDS,
                MM_TYPE_PROCESS, 0U) || !resident_two_v1678())
                return 2;
        /* After the transient original-MM error disappears, the
         * previously refused second process is still fully eligible
         * for real zero-copy DROP and in-place restoration. */
        PROC_SET_STATE(p, PROC_SLEEP);
        rc = proc_pure_mres_reclaim_v1611(0200UL, 02000UL, SLOT);
        if (rc != -1 || !check_owner_v1677(SLOT2_V1677,
            SOURCE2_V1677 + OMIT, SUFFIX,
            MM_TYPE_PACKED_PROCESS, 0U) || PROC_TRANSITION(q) ||
            VM_PDP6_BASE(q) || proc_storage_expect_v30(SLOT2_V1677,
            PROC_STORAGE_PACKED))
                return 3;
        PROC_SET_STATE(q, PROC_SRUN);
        proc_sched_cursor = PROC_SCHED_SWAP_REQUEST | SLOT2_V1677;
        rc = proc_pure_mres_service_v1611();
        if (rc != (int)(01000UL | SLOT2_V1677) ||
            proc_sched_cursor != (01000UL | SLOT2_V1677) ||
            PROC_TRANSITION(q) || VM_PDP6_BASE(q) != SOURCE2_V1677 ||
            !check_owner_v1677(SLOT2_V1677, SOURCE2_V1677,
                WORDS, MM_TYPE_PROCESS, 0U) ||
            pi_depth_v1381 ||
            pi_disable_count_v1381 != pi_restore_count_v1381)
                return 4;
        return 0;
}

int
main(void)
{
        unsigned int kind;
        int rc;
        for (kind = 1U; kind <= 2U; ++kind) {
            rc = case_precommit_v1678(kind);
            if (rc)
                return (int)(01000U + kind * 0100U + (unsigned int)rc);
        }
        return 0;
}
