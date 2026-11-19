/*
 * Actual KCC PDP-6 v1659 MM-backed bitmap probe and codec oracle.
 * This extends the original v1384 source-linked process/MM fixture.
 * Fault wrappers leave the actual original DROP/rebase untouched.
 * No compressed owner is ever published by the experimental probe.
 */
extern int proc_pure_bitmap_probe_v1659(unsigned int, kword_t *);
extern void bitmap_encode_v1451(kword_t, kword_t, kword_t);
#define PURE_BITMAP_NO_GAIN_V1659 (-6)

static unsigned int fault_kind_v1659;
static unsigned int fault_hits_v1659;
static unsigned int allocations_v1659;
static kword_t requested_v1659;

int
mm_bmap_alloc_v1659(kword_t words, kword_t align, unsigned int type,
    unsigned int owner, unsigned int preference, kword_t *basep)
{
        kword_t output = RESTORE;
        requested_v1659 = words;
        ++allocations_v1659;
        if (!basep || words == 0UL || words >= SUFFIX ||
            align != 1UL || type != MM_TYPE_PACKED_PROCESS ||
            owner != SLOT || preference != MM_ALLOC_HIGH)
                return MM_ERR_INVAL;
        if (fault_kind_v1659 == 1U) {
                ++fault_hits_v1659;
                return MM_ERR_NOMEM;
        }
        if (fault_kind_v1659 == 9U) {
                /* Invalid allocator witness: overlaps authoritative
                 * RAW despite presenting an allocated MM descriptor.
                 * The probe must reject before touching any source.
                 */
                ++fault_hits_v1659;
                output = SOURCE + OMIT + 010UL;
        }
        if (find_extent(RESTORE) >= 0 || mm_extent_count != 1)
                return MM_ERR_NOMEM;
        add_extent(output, words, type);
        *basep = output;
        return MM_OK;
}

int
mm_bmap_pin_v1659(kword_t base)
{
        if (fault_kind_v1659 == 2U && base == RESTORE) {
                ++fault_hits_v1659;
                return MM_ERR_BUSY;
        }
        return mm_pin(base);
}

int
mm_bmap_unpin_v1659(kword_t base)
{
        if ((fault_kind_v1659 == 3U && base == RESTORE) ||
            (fault_kind_v1659 == 5U && base == SOURCE + OMIT)) {
                ++fault_hits_v1659;
                return MM_ERR_BUSY;
        }
        return mm_unpin(base);
}

int
mm_bmap_free_v1659(kword_t base, unsigned int type,
    unsigned int owner)
{
        if (fault_kind_v1659 == 4U && base == RESTORE) {
                ++fault_hits_v1659;
                return MM_ERR_BUSY;
        }
        return mm_free(base, type, owner);
}

void
bitmap_encode_fault_v1659(kword_t source, kword_t words, kword_t dest)
{
        kword_t *packed = (kword_t *)(unsigned long)dest;
        bitmap_encode_v1451(source, words, dest);
        if (fault_kind_v1659 == 6U) {
                ++fault_hits_v1659;
                packed[1] ^= 1UL;
        } else if (fault_kind_v1659 == 8U) {
                /* Last of 22 control words has 12 live positions.
                 * Set a forbidden padding bit, without changing data.
                 */
                ++fault_hits_v1659;
                packed[27] |= 1UL;
        }
}

static kword_t
private_word_v1659(kword_t i)
{
        if (i == 0UL || i == 35UL || i == 36UL || i == 37UL ||
            i == 107UL || i == SUFFIX - 1UL || i == 252UL)
                return PATTERN + i;
        return 0UL;
}

static int
check_raw_v1659(void)
{
        kword_t i;
        kword_t *raw = (kword_t *)(unsigned long)(SOURCE + OMIT);
        for (i = 0UL; i < SUFFIX; ++i)
                if (raw[i] != private_word_v1659(i))
                        return 0;
        return 1;
}

static int
prepare_raw_v1659(void)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *raw = (kword_t *)(unsigned long)(SOURCE + OMIT);
        kword_t i;

        fault_kind_v1659 = 0U;
        fault_hits_v1659 = 0U;
        allocations_v1659 = 0U;
        requested_v1659 = 0UL;
        reset_prefix_v1384();
        if (proc_pure_ram_drop_v1381(SLOT) != MM_OK)
                return 1;
        for (i = 0UL; i < SUFFIX; ++i)
                raw[i] = private_word_v1659(i);
        PROC_SET_TRANSITION(p);
        if (mm_extent_count != 1 ||
            MM_EXTENT_BASE(&mm_extents[0]) != SOURCE + OMIT ||
            MM_EXTENT_WORDS(&mm_extents[0]) != SUFFIX ||
            MM_EXTENT_PINNED(&mm_extents[0]) ||
            !check_raw_v1659())
                return 2;
        return 0;
}

static int
check_owner_v1659(unsigned int pins, unsigned int extents)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *u = (kword_t *)(unsigned long)UAREA;
        if (mm_extent_count != (int)extents ||
            MM_EXTENT_BASE(&mm_extents[0]) != SOURCE + OMIT ||
            MM_EXTENT_WORDS(&mm_extents[0]) != SUFFIX ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PACKED_PROCESS ||
            MM_EXTENT_OWNER(&mm_extents[0]) != SLOT ||
            MM_EXTENT_PINNED(&mm_extents[0]) != pins ||
            VM_PDP6_BASE(p) || !PROC_TRANSITION(p) ||
            u[PROC_SWAP_BACKING_OFFSET] != BACKING ||
            swap_slots[SLOT].state != BACKING ||
            proc_storage_expect_v30(SLOT, PROC_STORAGE_PACKED) != 0 ||
            !check_raw_v1659())
                return 0;
        return 1;
}

static int
test_probe_v1659(unsigned int kind)
{
        kword_t packed = 0UL;
        int rc, setup;
        unsigned int pins = kind == 3U || kind == 4U || kind == 5U;
        unsigned int extents = kind == 3U || kind == 4U ? 2U : 1U;
        unsigned int expected_fault = kind != 0U && kind != 7U;

        setup = prepare_raw_v1659();
        if (setup)
                return 1;
        if (kind == 7U) {
                /* A full-density RAW is larger when bitmap encoded.
                 * The probe must reject before allocating anything.
                 */
                kword_t i;
                kword_t *raw = (kword_t *)(unsigned long)(SOURCE + OMIT);
                for (i = 0UL; i < SUFFIX; ++i)
                        raw[i] = PATTERN + i;
        }
        fault_kind_v1659 = kind;
        rc = proc_pure_bitmap_probe_v1659(SLOT, &packed);
        fault_kind_v1659 = 0U;
        if (kind == 0U) {
                if (rc != MM_OK || packed != 22UL + 7UL ||
                    requested_v1659 != packed || allocations_v1659 != 1U ||
                    !check_owner_v1659(0U, 1U) || fault_hits_v1659)
                        return 2;
        } else if (kind == 7U) {
                if (rc != PURE_BITMAP_NO_GAIN_V1659 || packed ||
                    allocations_v1659 || mm_extent_count != 1 ||
                    MM_EXTENT_PINNED(&mm_extents[0]) ||
                    !PROC_TRANSITION(&process_slots[SLOT]))
                        return 3;
        } else if (kind == 9U) {
                if (rc != MM_ERR_INVAL || packed ||
                    allocations_v1659 != 1U || fault_hits_v1659 != 1U ||
                    !check_owner_v1659(0U, 1U))
                        return 6;
        } else {
                if (rc != (kind == 1U ? MM_ERR_NOMEM :
                        ((kind == 6U || kind == 8U) ?
                            MM_ERR_INVAL : MM_ERR_BUSY)) ||
                    packed || allocations_v1659 != 1U ||
                    fault_hits_v1659 != expected_fault ||
                    !check_owner_v1659(pins, extents))
                        return 4;
                if (extents == 2U &&
                    (MM_EXTENT_BASE(&mm_extents[1]) != RESTORE ||
                     MM_EXTENT_WORDS(&mm_extents[1]) != 29UL ||
                     MM_EXTENT_TYPE(&mm_extents[1]) !=
                        MM_TYPE_PACKED_PROCESS ||
                     MM_EXTENT_OWNER(&mm_extents[1]) != SLOT ||
                     MM_EXTENT_PINNED(&mm_extents[1]) !=
                        (kind == 3U ? 1U : 0U)))
                        return 5;
        }
        return 0;
}

static int
test_duplicate_v1659(void)
{
        struct mm_extent duplicate;
        kword_t out = 0UL;

        if (prepare_raw_v1659())
                return 1;
        duplicate = mm_extents[0];
        mm_extents[1] = duplicate;
        mm_extent_count = 2;
        if (proc_pure_bitmap_probe_v1659(SLOT, &out) != MM_ERR_INVAL ||
            out || allocations_v1659 ||
            MM_EXTENT_PINNED(&mm_extents[0]) ||
            MM_EXTENT_PINNED(&mm_extents[1]) ||
            !PROC_TRANSITION(&process_slots[SLOT]))
                return 2;
        return 0;
}

/* v1657's ACTUAL six-owner MM geometry, reproduced under the native
 * PDP-6 source-linked probe. The physical word content remains checked
 * by the independent v1657 SIMH witness, not by this synthetic pattern.
 */
static int
test_3456_geometry_v1659(void)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *u = (kword_t *)(unsigned long)UAREA;
        kword_t *raw = (kword_t *)(unsigned long)(SOURCE + 01200UL);
        kword_t backing = ((kword_t)01200UL << PROC_SWAP_TEXT_SHIFT) |
            012345UL;
        kword_t encoded = 0UL, i;
        int rc;

        if (prepare_raw_v1659())
                return 1;
        p->vm_state = (010000UL << PROC_HALF_SHIFT);
        swap_slots[SLOT].state = backing;
        u[PROC_SWAP_BACKING_OFFSET] = backing;
        mm_extents[0].span = (06600UL << 18U) | (SOURCE + 01200UL);
        for (i = 0UL; i < 06600UL; ++i)
                raw[i] = 0UL;
        for (i = 0UL; i < 65UL; ++i)
                raw[i * 050UL] = PATTERN + i;
        rc = proc_pure_bitmap_probe_v1659(SLOT, &encoded);
        if (rc != MM_OK || encoded != 161UL ||
            requested_v1659 != 161UL || allocations_v1659 != 1U ||
            mm_extent_count != 1 ||
            MM_EXTENT_BASE(&mm_extents[0]) != SOURCE + 01200UL ||
            MM_EXTENT_WORDS(&mm_extents[0]) != 06600UL ||
            MM_EXTENT_PINNED(&mm_extents[0]) ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PACKED_PROCESS ||
            !PROC_TRANSITION(p) || VM_PDP6_BASE(p) ||
            u[PROC_SWAP_BACKING_OFFSET] != backing ||
            proc_storage_expect_v30(SLOT, PROC_STORAGE_PACKED) != 0)
                return 2;
        for (i = 0UL; i < 06600UL; ++i)
                if (raw[i] != ((i % 050UL == 0UL && i / 050UL < 65UL) ?
                    PATTERN + i / 050UL : 0UL))
                        return 3;
        return 0;
}

int
main(void)
{
        unsigned int kind;
        int rc;

        for (kind = 0U; kind <= 9U; ++kind) {
                rc = test_probe_v1659(kind);
                if (rc)
                        return (int)(01000U + kind * 0100U +
                            (unsigned int)rc);
        }
        rc = test_duplicate_v1659();
        if (rc)
                return 03000 + rc;
        rc = test_3456_geometry_v1659();
        if (rc)
                return 04000 + rc;
        return 0;
}
