/*
 * v1648: source-linked native PDP-6 FULL restore fault and retry matrix.
 *
 * Appended after the real v1384 and v1395 native fixtures.  All fault
 * injection is applied to the compiled production FULL C transaction,
 * not to MM assembly, the scheduler or a production image.
 *
 * This is intentionally ANSI C89 (and uses only ASCII characters).
 */

static unsigned int fault_kind_v1648;
static unsigned int fault_calls_v1648;

/* The old v1395 wrapper retains its original target-free fault cases. */
int
mm_free_fault_v1648(kword_t base, unsigned int type, unsigned int owner)
{
        if ((fault_kind_v1648 == 7U || fault_kind_v1648 == 8U) &&
            base == SOURCE + OMIT && type == MM_TYPE_PACKED_PROCESS &&
            owner == SLOT) {
                ++fault_calls_v1648;
                return fault_kind_v1648 == 7U ?
                    MM_ERR_BUSY : MM_ERR_INVAL;
        }
        return mm_free_fault_v1395(base, type, owner);
}

/* A new full-APR pin refusal must release its newly allocated owner. */
int
mm_pin_fault_v1648(kword_t base)
{
        if (fault_kind_v1648 == 9U && base == RESTORE) {
                ++fault_calls_v1648;
                return MM_ERR_BUSY;
        }
        return mm_pin(base);
}

static int
check_packed_v1648(void)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *u = (kword_t *)(unsigned long)UAREA;

        if (mm_extent_count != 1 ||
            MM_EXTENT_BASE(&mm_extents[0]) != SOURCE + OMIT ||
            MM_EXTENT_WORDS(&mm_extents[0]) != SUFFIX ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PACKED_PROCESS ||
            MM_EXTENT_OWNER(&mm_extents[0]) != SLOT ||
            MM_EXTENT_PINNED(&mm_extents[0]) ||
            VM_PDP6_BASE(p) || !PROC_TRANSITION(p) ||
            u[PROC_SWAP_BACKING_OFFSET] != BACKING ||
            proc_storage_expect_v30(SLOT, PROC_STORAGE_PACKED) != 0 ||
            !check_suffix_v1384())
                return 0;
        return 1;
}

static int
check_restored_v1648(void)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *u = (kword_t *)(unsigned long)UAREA;
        kword_t *image = (kword_t *)(unsigned long)RESTORE;
        unsigned int i;

        if (mm_extent_count != 1 ||
            MM_EXTENT_BASE(&mm_extents[0]) != RESTORE ||
            MM_EXTENT_WORDS(&mm_extents[0]) != WORDS ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PROCESS ||
            MM_EXTENT_OWNER(&mm_extents[0]) != SLOT ||
            MM_EXTENT_PINNED(&mm_extents[0]) ||
            VM_PDP6_BASE(p) != RESTORE || PROC_TRANSITION(p) ||
            u[PROC_SWAP_BACKING_OFFSET] != 0UL ||
            proc_storage_expect_v30(SLOT, PROC_STORAGE_RESIDENT) != 0)
                return 0;
        for (i = 020U; i < WORDS; ++i) {
                kword_t expected = i < OMIT ? TEXT_PATTERN : PATTERN + i;
                if (image[i] != expected)
                        return 0;
        }
        return 1;
}

static int
case_full_retry_v1648(unsigned int kind)
{
        struct proc *p = &process_slots[SLOT];
        int expected = kind == 8U ? MM_ERR_INVAL : MM_ERR_BUSY;
        int rc;

        fault_kind_v1395 = 0U;
        fault_calls_v1395 = 0U;
        fault_kind_v1648 = 0U;
        fault_calls_v1648 = 0U;
        reset_prefix_v1384();
        if (proc_pure_ram_drop_v1381(SLOT) != MM_OK)
                return 1;
        PROC_SET_TRANSITION(p);
        if (!check_packed_v1648())
                return 2;

        fault_kind_v1648 = kind;
        rc = proc_pure_ram_restore_v1391(SLOT, accept_payload_v1395);
        if (rc != expected || fault_calls_v1648 != 1U)
                return 3;
        /* Both possible rollback resources are authoritative: the raw
         * suffix is still singly owned, the provisional FULL APR is gone.
         */
        if (!check_packed_v1648())
                return 4;

        fault_kind_v1648 = 0U;
        if (proc_pure_ram_restore_v1391(SLOT, accept_payload_v1395) !=
            MM_OK)
                return 5;
        if (!check_restored_v1648())
                return 6;
        return 0;
}

int
main(void)
{
        unsigned int kind;
        int rc;

        fault_kind_v1648 = 0U;
        fault_calls_v1648 = 0U;
        rc = baseline_main_v1395();
        if (rc != 0)
                return rc;
        for (kind = 7U; kind <= 9U; ++kind) {
                rc = case_full_retry_v1648(kind);
                if (rc != 0)
                        return (int)(kind * 0100U + (unsigned int)rc);
        }
        return 0;
}
