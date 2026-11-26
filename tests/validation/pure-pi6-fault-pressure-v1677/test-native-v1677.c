/* v1677 native PDP-6: a refused rebase unpin must not affect a healthy
 * second PACKED owner. The production C transaction and MM assembler
 * are linked, not reimplemented. This is not the physical PI6 gate.
 */
#define SLOT2_V1677 (SLOT + 1U)
#define SOURCE2_V1677 0100000UL
#define UAREA2_V1677 0120000UL

static unsigned int fault_second_v1677;
static unsigned int fault_hits_v1677;

int
mm_unpin_fault_v1677(kword_t base)
{
        if (base == SOURCE2_V1677 + OMIT && fault_second_v1677) {
                ++fault_hits_v1677;
                if (fault_second_v1677 == 1U) {
                        /* MM unpin did commit, but the reply was lost. */
                        if (mm_unpin(base) != MM_OK)
                                return MM_ERR_INVAL;
                }
                return MM_ERR_BUSY;
        }
        return mm_unpin_fault_v1658(base);
}

static int
check_owner_v1677(unsigned int slot, kword_t base, kword_t words,
    unsigned int kind, unsigned int pins)
{
        int i;
        unsigned int found = 0U;
        for (i = 0; i < mm_extent_count; ++i) {
                struct mm_extent *e = &mm_extents[i];
                if (MM_EXTENT_OWNER(e) != slot)
                        continue;
                if (++found != 1U || MM_EXTENT_BASE(e) != base ||
                    MM_EXTENT_WORDS(e) != words ||
                    MM_EXTENT_TYPE(e) != kind ||
                    MM_EXTENT_PINS(e) != pins)
                        return 0;
        }
        return found == 1U;
}

static int
case_two_owners_v1677(unsigned int fault)
{
        struct proc *p = &process_slots[SLOT];
        struct proc *q = &process_slots[SLOT2_V1677];
        kword_t *u = (kword_t *)(unsigned long)UAREA2_V1677;
        kword_t *s = (kword_t *)(unsigned long)SOURCE2_V1677;
        unsigned int i;
        int rc;

        reset_service_v1611();
        drop_fault_v1658 = 0U;
        fault_second_v1677 = fault;
        fault_hits_v1677 = 0U;
        /* The actual MM rebase scans a sorted two-descriptor table. */
        add_extent(SOURCE2_V1677, WORDS, MM_TYPE_PROCESS);
        mm_extents[1].meta =
            (mm_extents[1].meta & ~((kword_t)0777UL)) |
            SLOT2_V1677;
        /* v1922 validates arena bounds against actual physical core. */
        mm_core_words = 0140000UL;
        mm_arenas[0] = ((kword_t)0100000UL << 18U) | 040000UL;
        for (i = 0U; i < WORDS; ++i)
                s[i] = i < OMIT ? TEXT_PATTERN : PATTERN + i;
        for (i = 0U; i < PROC_UAREA_WORDS; ++i)
                u[i] = 0UL;
        /* v1924: both owners refer to the same original provider. */
        u[PROC_CRED_OFFSET] =
            ((kword_t *)(unsigned long)UAREA)[PROC_CRED_OFFSET];
        q->meta = (UAREA2_V1677 << PROC_HALF_SHIFT) |
            ((kword_t)PROC_F_UAREA << PROC_FLAGS_SHIFT);
        q->vm_state = (WORDS << PROC_HALF_SHIFT) | SOURCE2_V1677;
        q->sched = (kword_t)PROC_SLEEP << PROC_STATE_SHIFT;
        swap_slots[SLOT2_V1677].state = BACKING;
        proc_high_slot = SLOT2_V1677 + 1U;
        rc = proc_pure_mres_reclaim_v1611(0200UL, 02000UL, 0U);
        fault_second_v1677 = 0U;
        /* v1916: hard second-owner refusal terminates pressure;
         * a proved lost-success unpin still permits ordinary pressure. */
        if (rc != (fault == 2U ? MM_ERR_BUSY : -1) ||
            fault_hits_v1677 != (fault ? 1U : 0U) ||
            !check_owner_v1677(SLOT, SOURCE + OMIT, SUFFIX,
                MM_TYPE_PACKED_PROCESS, 0U) ||
            !check_owner_v1677(SLOT2_V1677,
                SOURCE2_V1677 + OMIT, SUFFIX,
                MM_TYPE_PACKED_PROCESS, fault == 2U ? 1U : 0U))
                return 1;
        if (PROC_TRANSITION(p) || VM_PDP6_BASE(p) ||
            PROC_TRANSITION(q) != (fault == 2U) ||
            VM_PDP6_BASE(q) ||
            proc_storage_expect_v30(SLOT, PROC_STORAGE_PACKED) ||
            proc_storage_expect_v30(SLOT2_V1677,
                PROC_STORAGE_PACKED) ||
            pi_depth_v1381 ||
            pi_disable_count_v1381 != pi_restore_count_v1381)
                return 2;
        /* A refused pin on the second owner may not block the first
         * owner's independent slot-0 restore or advertise the second.
         */
        PROC_SET_STATE(p, PROC_SRUN);
        proc_sched_cursor = PROC_SCHED_SWAP_REQUEST | SLOT;
        rc = PURE_TEST_SERVICE_CALL_V1902();
        if (rc != (int)(01000UL | SLOT) ||
            proc_sched_cursor != (01000UL | SLOT) ||
            !check_owner_v1677(SLOT, SOURCE, WORDS,
                MM_TYPE_PROCESS, 0U) ||
            !check_owner_v1677(SLOT2_V1677,
                SOURCE2_V1677 + OMIT, SUFFIX,
                MM_TYPE_PACKED_PROCESS, fault == 2U ? 1U : 0U) ||
            PROC_TRANSITION(p) || VM_PDP6_BASE(p) != SOURCE ||
            PROC_TRANSITION(q) != (fault == 2U) ||
            pi_depth_v1381 ||
            pi_disable_count_v1381 != pi_restore_count_v1381)
                return 3;
        if (fault == 2U) {
                /* A permanently pinned owner is never retried or
                 * cleared by a second reclaim scan. */
                (void)proc_pure_mres_reclaim_v1611(0200UL, 02000UL,
                    SLOT);
                if (!PROC_TRANSITION(q) ||
                    !check_owner_v1677(SLOT2_V1677,
                        SOURCE2_V1677 + OMIT, SUFFIX,
                        MM_TYPE_PACKED_PROCESS, 1U))
                        return 4;
        }
        return 0;
}

int
main(void)
{
        unsigned int fault;
        int rc = 0;
#ifndef V1677_MUTANT_ONLY
        rc = baseline_main_v1677();
        if (rc)
                return 01000 + rc;
#endif
        for (fault = 0U; fault <= 2U; ++fault) {
                rc = case_two_owners_v1677(fault);
                if (rc)
                        return 02000 + (int)(fault * 0100U) + rc;
        }
        return 0;
}
