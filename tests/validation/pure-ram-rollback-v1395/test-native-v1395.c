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

int
mm_unpin_fault_v1395(kword_t base)
{
        if ((fault_kind_v1395 == 1U && base == RESTORE) ||
            (fault_kind_v1395 == 3U && base == SOURCE + OMIT) ||
            (fault_kind_v1395 == 4U && base == RESTORE)) {
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
        int rc;

        reset_prefix_v1384();
        if (proc_pure_ram_drop_v1381(SLOT) != MM_OK)
                return 1;
        PROC_SET_TRANSITION(p);
        fault_kind_v1395 = kind;
        fault_calls_v1395 = 0U;
        rc = proc_pure_ram_restore_v1391(SLOT,
            kind == 4U ? accept_payload_v1395 : reject_payload_v1395);
        if (rc != MM_ERR_BUSY || fault_calls_v1395 != 1U ||
            !PROC_TRANSITION(p) ||
            (kind != 4U && (VM_PDP6_BASE(p) ||
                u[PROC_SWAP_BACKING_OFFSET] != BACKING ||
                proc_storage_expect_v30(SLOT, PROC_STORAGE_PACKED))) ||
            (kind == 4U && (VM_PDP6_BASE(p) != RESTORE ||
                proc_storage_expect_v30(SLOT, PROC_STORAGE_RESIDENT))))
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
            !MM_EXTENT_PINNED(&mm_extents[0])))
                return 6;
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
        return 0;
}
