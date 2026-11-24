/* Native PDP-6 fail-closed PURE restore rollback regression.
 * Reuse the v1384 source-linked MM/PROC fixture, with faults only in the
 * v1391 transaction's real MM release calls. This adds no production data.
 */
/* This extension is appended to the source-linked v1384 fixture before KCC
 * compilation, keeping KCC's existing eight-level header nesting limit. */

extern int proc_pure_ram_restore_v1391(unsigned int,
    int (*)(kword_t, kword_t, kword_t, kword_t));

static unsigned int fault_kind_v1395;
static unsigned int fault_calls_v1395;

/* Isolate the prepublication MM rebase failure from failure of the
 * subsequent cleanup unpin. Do not modify the real MM assembly helper. */
int
mm_pure_rebase_fault_v1397(kword_t base, unsigned int owner,
    kword_t prefix, kword_t words)
{
        if (fault_kind_v1395 == 5U || fault_kind_v1395 == 6U)
                return MM_ERR_INVAL;
        return mm_pure_rebase_pinned_v1381(base, owner, prefix, words);
}

int
mm_unpin_fault_v1395(kword_t base)
{
        if (fault_kind_v1395 == 12U && base == RESTORE &&
            fault_calls_v1395 == 0U) {
                if (mm_unpin(base) != MM_OK)
                        return MM_ERR_INVAL;
                ++fault_calls_v1395;
                return MM_ERR_BUSY; /* the original decrement committed */
        }
        if ((fault_kind_v1395 == 1U && base == RESTORE) ||
            (fault_kind_v1395 == 3U && base == SOURCE + OMIT) ||
            (fault_kind_v1395 == 4U && base == RESTORE &&
             fault_calls_v1395 == 0U) ||
            (fault_kind_v1395 == 10U && base == RESTORE) ||
            (fault_kind_v1395 == 11U && base == SOURCE + OMIT) ||
            (fault_kind_v1395 == 5U && base == SOURCE)) {
                ++fault_calls_v1395;
                return MM_ERR_BUSY;
        }
        return mm_unpin(base);
}

int
mm_free_fault_v1395(kword_t base, unsigned int type, unsigned int owner)
{
        if (fault_kind_v1395 == 2U && base == RESTORE) {
                ++fault_calls_v1395;
                return MM_ERR_BUSY;
        }
        return mm_free(base, type, owner);
}

static int
reject_payload_v1395(kword_t backing, kword_t base, kword_t stable,
    kword_t capacity)
{
        if (backing != BACKING || base != RESTORE || stable != UAREA ||
            capacity != WORDS)
                return -2;
        return -1;
}

static int
accept_payload_v1395(kword_t backing, kword_t base, kword_t stable,
    kword_t capacity)
{
        kword_t *image = (kword_t *)(unsigned long)base;
        unsigned int i;
        if (backing != BACKING || base != RESTORE || stable != UAREA ||
            capacity != WORDS)
                return -1;
        for (i = 020U; i < WORDS; ++i)
                image[i] = i < OMIT ? TEXT_PATTERN : 07777UL;
        return 0;
}

static int
case_v1395(unsigned int kind)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *u = (kword_t *)(unsigned long)UAREA;
        vnode_t old_root;
        int rc;

        /* The preceding case may have deliberately left a pin refusal.
         * Prepare each fresh resident image without injected faults. */
        fault_kind_v1395 = 0U;
        fault_calls_v1395 = 0U;
        reset_prefix_v1384();
        if (proc_pure_ram_drop_v1381(SLOT) != MM_OK)
                return 1;
        PROC_SET_TRANSITION(p);
        if (kind == 1U) {
                /*
                 * Source loss must be detected by the real bounded FULL
                 * transaction before it allocates or pins a destination.
                 * The PACKED suffix must survive for a later valid retry.
                 */
                old_root = vfs_mount_root_base[0];
                vfs_mount_root_base[0] = 0UL;
                rc = proc_pure_ram_restore_v1391(SLOT,
                    reject_payload_v1395);
                vfs_mount_root_base[0] = old_root;
                if (rc != MM_ERR_INVAL || !PROC_TRANSITION(p) ||
                    mm_extent_count != 1 ||
                    MM_EXTENT_TYPE(&mm_extents[0]) !=
                        MM_TYPE_PACKED_PROCESS ||
                    MM_EXTENT_PINNED(&mm_extents[0]) ||
                    VM_PDP6_BASE(p) ||
                    u[PROC_SWAP_BACKING_OFFSET] != BACKING ||
                    proc_storage_expect_v30(SLOT, PROC_STORAGE_PACKED))
                        return 7;
        }
        fault_kind_v1395 = kind;
        fault_calls_v1395 = 0U;
        rc = proc_pure_ram_restore_v1391(SLOT,
            kind == 4U ? accept_payload_v1395 : reject_payload_v1395);
        if (rc != MM_ERR_BUSY || fault_calls_v1395 != 1U ||
            !PROC_TRANSITION(p) || VM_PDP6_BASE(p) ||
            u[PROC_SWAP_BACKING_OFFSET] != BACKING ||
            proc_storage_expect_v30(SLOT, PROC_STORAGE_PACKED))
                return 2;
        if (kind == 1U && (mm_extent_count != 2 ||
            !MM_EXTENT_PINNED(&mm_extents[0]) ||
            !MM_EXTENT_PINNED(&mm_extents[1])))
                return 3;
        if (kind == 2U && (mm_extent_count != 2 ||
            !MM_EXTENT_PINNED(&mm_extents[0]) ||
            MM_EXTENT_PINNED(&mm_extents[1])))
                return 4;
        if (kind == 3U && (mm_extent_count != 1 ||
            !MM_EXTENT_PINNED(&mm_extents[0])))
                return 5;
        if (kind == 4U && (mm_extent_count != 1 ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PACKED_PROCESS ||
            MM_EXTENT_BASE(&mm_extents[0]) != SOURCE + OMIT ||
            MM_EXTENT_PINNED(&mm_extents[0]) ||
            !check_suffix_v1384()))
                return 6;
        /* v1654: the target unpin failure must happen before
         * destructive source release and RESIDENT publication.
         * Its one-shot refusal can be rolled back with no leaked
         * full target; a later retry must recover the exact image.
         */
        if (kind == 4U) {
                fault_kind_v1395 = 0U;
                if (proc_pure_ram_restore_v1391(SLOT,
                    accept_payload_v1395) != MM_OK ||
                    PROC_TRANSITION(p) ||
                    VM_PDP6_BASE(p) != RESTORE ||
                    proc_storage_expect_v30(SLOT,
                        PROC_STORAGE_RESIDENT) != 0 ||
                    mm_extent_count != 1 ||
                    MM_EXTENT_PINNED(&mm_extents[0]) ||
                    !check_suffix_v1384())
                        return 8;
        }
        return 0;
}

static int
case_drop_unpin_v1397(unsigned int kind)
{
        struct proc *p = &process_slots[SLOT];
        int rc;

        reset_prefix_v1384();
        fault_kind_v1395 = kind;
        fault_calls_v1395 = 0U;
        rc = proc_pure_ram_drop_v1381(SLOT);
        if (rc != (kind == 5U ? MM_ERR_BUSY : MM_ERR_INVAL) ||
            fault_calls_v1395 != (kind == 5U ? 1U : 0U) ||
            mm_extent_count != 1 || VM_PDP6_BASE(p) != SOURCE ||
            MM_EXTENT_BASE(&mm_extents[0]) != SOURCE ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PROCESS ||
            MM_EXTENT_PINNED(&mm_extents[0]) != (kind == 5U ? 1U : 0U) ||
            proc_storage_expect_v30(SLOT, PROC_STORAGE_RESIDENT) != 0 ||
            !PROC_TRANSITION(p))
                return 1;
        return 0;
}

/*
 * v1610: a real slot-0 wake may restore RUN only after the dormant
 * suffix has been produced from SLEEP. A non-slot-0 caller, or an
 * attempt to DROP RUN directly, must not modify either MM owner.
 */
static int
case_slot0_full_v1610(void)
{
        struct proc *p = &process_slots[SLOT];

        fault_kind_v1395 = 0U;
        reset_prefix_v1384();
        PROC_SET_STATE(p, PROC_SRUN);
        proc_current_slot = 0UL;
        if (proc_pure_ram_drop_v1381(SLOT) != MM_ERR_INVAL ||
            VM_PDP6_BASE(p) != SOURCE ||
            proc_storage_expect_v30(SLOT, PROC_STORAGE_RESIDENT) != 0 ||
            mm_extent_count != 1 ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PROCESS)
                return 1;
        PROC_SET_STATE(p, PROC_SLEEP);
        if (proc_pure_ram_drop_v1381(SLOT) != MM_OK)
                return 2;
        PROC_SET_TRANSITION(p);
        PROC_SET_STATE(p, PROC_SRUN);
        proc_current_slot = SLOT;
        if (proc_pure_ram_restore_v1391(SLOT, accept_payload_v1395) !=
                MM_ERR_INVAL ||
            mm_extent_count != 1 ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PACKED_PROCESS ||
            VM_PDP6_BASE(p) || !PROC_TRANSITION(p) ||
            proc_storage_expect_v30(SLOT, PROC_STORAGE_PACKED) != 0)
                return 3;
        proc_current_slot = 0UL;
        if (proc_pure_ram_restore_v1391(SLOT, accept_payload_v1395) !=
                MM_OK ||
            VM_PDP6_BASE(p) != RESTORE ||
            proc_storage_expect_v30(SLOT, PROC_STORAGE_RESIDENT) != 0 ||
            PROC_TRANSITION(p) ||
            mm_extent_count != 1 ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PROCESS ||
            MM_EXTENT_BASE(&mm_extents[0]) != RESTORE ||
            !check_suffix_v1384())
                return 4;
        return 0;
}

static int
case_lost_target_unpin_v1917(void)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *u = (kword_t *)(unsigned long)UAREA;

        fault_kind_v1395 = 0U;
        fault_calls_v1395 = 0U;
        reset_prefix_v1384();
        if (proc_pure_ram_drop_v1381(SLOT) != MM_OK)
                return 1;
        PROC_SET_TRANSITION(p);
        fault_kind_v1395 = 12U;
        if (proc_pure_ram_restore_v1391(SLOT, accept_payload_v1395) !=
            MM_ERR_BUSY || fault_calls_v1395 != 1U ||
            !PROC_TRANSITION(p) || VM_PDP6_BASE(p) ||
            mm_extent_count != 1 ||
            MM_EXTENT_BASE(&mm_extents[0]) != SOURCE + OMIT ||
            MM_EXTENT_PINNED(&mm_extents[0]) ||
            u[PROC_FINALIZE_OFFSET] || !check_suffix_v1384())
                return 2;
        fault_kind_v1395 = 0U;
        if (proc_pure_ram_restore_v1391(SLOT, accept_payload_v1395) !=
            MM_OK || PROC_TRANSITION(p) || VM_PDP6_BASE(p) != RESTORE ||
            mm_extent_count != 1 || MM_EXTENT_PINNED(&mm_extents[0]))
                return 3;
        return 0;
}

int
main(void)
{
        unsigned int kind;
        int rc;
        for (kind = 1U; kind <= 4U; ++kind) {
            rc = case_v1395(kind);
            if (rc != 0)
                return (int)(kind * 0100U + (unsigned int)rc);
        }
        for (kind = 5U; kind <= 6U; ++kind) {
            rc = case_drop_unpin_v1397(kind);
            if (rc != 0)
                return (int)(kind * 0100U + (unsigned int)rc);
        }
        rc = case_slot0_full_v1610();
        if (rc)
                return 01600 + rc;
        rc = case_lost_target_unpin_v1917();
        if (rc)
                return 01700 + rc;
        return 0;
}
