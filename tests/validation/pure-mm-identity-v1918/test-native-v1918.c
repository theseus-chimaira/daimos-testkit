/* Source-linked DROP/PREFIX ownership uncertainty, v1918. */
static unsigned int fault_v1918;
static unsigned int unpins_v1918;

int
rebase_reply_v1918(kword_t base, unsigned int owner,
    kword_t prefix, kword_t words)
{
        int rc = mm_pure_rebase_pinned_v1381(base, owner, prefix, words);
        if (rc == MM_OK && fault_v1918 == 1U)
                return MM_ERR_BUSY;
        return rc;
}

int
claim_reply_v1918(kword_t base, unsigned int owner,
    kword_t prefix, kword_t words)
{
        int rc = mm_pure_claim_prefix_v1384(base, owner, prefix, words);
        if (rc == MM_OK && fault_v1918 == 2U)
                return MM_ERR_BUSY;
        return rc;
}

int
commit_reply_v1918(kword_t base, unsigned int owner,
    kword_t prefix, kword_t words)
{
        int rc = mm_pure_commit_prefix_v1384(base, owner, prefix, words);
        if (rc == MM_OK && fault_v1918 == 3U)
                return MM_ERR_BUSY;
        return rc;
}

int
release_reply_v1918(kword_t base, unsigned int owner,
    kword_t prefix, kword_t words)
{
        int rc = mm_pure_release_prefix_v1384(base, owner, prefix, words);
        if (rc == MM_OK && fault_v1918 == 4U)
                mm_extents[0].meta =
                    (mm_extents[0].meta & ~MM_OWNER_MASK) | (SLOT + 1U);
        if (rc == MM_OK && fault_v1918 == 5U)
                return MM_ERR_BUSY;
        return rc;
}

int
unpin_reply_v1918(kword_t base)
{
        ++unpins_v1918;
        return mm_unpin(base);
}

static int
load_v1918(kword_t backing, kword_t base, kword_t uarea, kword_t prefix)
{
        int rc = prefix_plain_v1384(backing, base, uarea, prefix);
        if (!rc && fault_v1918 == 6U)
                (void)mm_pin(base);
        if (fault_v1918 == 4U || fault_v1918 == 5U)
                return -1;
        return rc;
}

/* Every fault is injected after a real MM operation, not instead of it.
 * Check the original physical identity, mode, escrow and exact pin count. */
static int
case_v1918(unsigned int kind)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *u = (kword_t *)(unsigned long)UAREA;
        unsigned int type, owner, pins;
        kword_t base, words, escrow;
        int rc, expected;

        reset_prefix_v1384();
        fault_v1918 = kind == 1U ? kind : 0U;
        unpins_v1918 = 0U;
        rc = proc_pure_ram_drop_v1381(SLOT);
        if (rc != MM_OK || PROC_TRANSITION(p) || VM_PDP6_BASE(p) ||
            proc_storage_expect_v30(SLOT, PROC_STORAGE_PACKED) ||
            mm_extent_count != 1 || MM_EXTENT_BASE(&mm_extents[0]) != SOURCE + OMIT ||
            MM_EXTENT_WORDS(&mm_extents[0]) != SUFFIX ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PACKED_PROCESS ||
            MM_EXTENT_OWNER(&mm_extents[0]) != SLOT ||
            MM_EXTENT_PINS(&mm_extents[0]) || unpins_v1918 != 1U ||
            u[PROC_FINALIZE_OFFSET] || !check_suffix_v1384())
                return 1;
        if (kind == 1U)
                return 0;
        PROC_SET_TRANSITION(p);
        fault_v1918 = kind;
        unpins_v1918 = 0U;
        rc = proc_pure_restore_v1384(SLOT, load_v1918);
        expected = kind == 3U ? MM_OK : MM_ERR_BUSY;
        if (rc != expected || mm_extent_count != 1 ||
            pi_depth_v1381 || pi_disable_count_v1381 != pi_restore_count_v1381 ||
            !check_suffix_v1384() || alloc_count_v1381 || free_count_v1381)
                return 2;
        type = kind == 3U ? MM_TYPE_PROCESS : MM_TYPE_PACKED_PROCESS;
        owner = kind == 4U ? SLOT + 1U : SLOT;
        pins = kind == 4U ? 1U : (kind == 6U ? 2U : 0U);
        base = kind == 3U || kind == 6U ? SOURCE : SOURCE + OMIT;
        words = kind == 3U || kind == 6U ? WORDS : SUFFIX;
        escrow = kind == 4U || kind == 6U ?
            PROC_PURE_INPLACE_ESCROW_V1919(SOURCE + OMIT,
                PROC_PURE_PREFIX_TAG_V1919) : 0UL;
        if (MM_EXTENT_TYPE(&mm_extents[0]) != type ||
            MM_EXTENT_OWNER(&mm_extents[0]) != owner ||
            MM_EXTENT_PINS(&mm_extents[0]) != pins ||
            MM_EXTENT_BASE(&mm_extents[0]) != base ||
            MM_EXTENT_WORDS(&mm_extents[0]) != words ||
            u[PROC_FINALIZE_OFFSET] != escrow)
                return 3;
        if (kind == 3U) {
                if (PROC_TRANSITION(p) || VM_PDP6_BASE(p) != SOURCE ||
                    proc_storage_expect_v30(SLOT, PROC_STORAGE_RESIDENT) ||
                    u[PROC_SWAP_BACKING_OFFSET] || unpins_v1918)
                        return 4;
        } else if (!PROC_TRANSITION(p) || VM_PDP6_BASE(p) ||
            proc_storage_expect_v30(SLOT, PROC_STORAGE_PACKED) ||
            u[PROC_SWAP_BACKING_OFFSET] != BACKING ||
            unpins_v1918 != (kind == 2U || kind == 5U ? 1U : 0U))
                return 5;
        if (prefix_reads_v1384 != (kind == 2U ? 0U : 1U))
                return 6;
        return 0;
}

extern kword_t proc_pure_owner_v1918(unsigned int, unsigned int,
    kword_t, kword_t, unsigned int);

/* Geometry proof: exercise discovery and exact lookup, including a
 * foreign range BEFORE the user extent in the sorted descriptor table. */
static int
geometry_v1918(unsigned int kind)
{
        kword_t pi, result, expected;
        struct mm_extent original;
        reset_prefix_v1384();
        original = mm_extents[0];
        mm_extents[1] = original;
        mm_extent_count = 2;
        mm_extents[0].span = (0200UL << 18U) | (SOURCE - 0200UL);
        mm_extents[0].meta = ((kword_t)MM_TYPE_MODULE << MM_TYPE_SHIFT) | SLOT;
        expected = 0UL;
        switch (kind) {
        case 1U: /* adjacent, independent module namespace */
                expected = SOURCE;
                break;
        case 2U: /* preceding overlapping foreign module */
                mm_extents[0].span = (0400UL << 18U) | (SOURCE - 0200UL);
                break;
        case 3U: /* same owner, second user extent */
                mm_extents[0].meta = ((kword_t)MM_TYPE_PROCESS << MM_TYPE_SHIFT) | SLOT;
                break;
        case 4U:
                mm_extent_capacity = 1U;
                break;
        case 5U:
                mm_extents[0].span = SOURCE - 0200UL;
                break;
        case 6U: /* extent crossing physical address limit */
                mm_extents[0].span = (0400UL << 18U) | 0777600UL;
                break;
        case 7U: /* independent kernel allocation namespace */
                mm_extents[0].meta = ((kword_t)MM_TYPE_KERNEL_DYNAMIC << MM_TYPE_SHIFT) | SLOT;
                expected = SOURCE;
                break;
        }
        pi = mach_pi_disable();
        result = proc_pure_owner_v1918(SLOT, MM_TYPE_PROCESS, 0UL, WORDS, 0U);
        if (result != expected) {
                mach_pi_restore(pi);
                return 1;
        }
        result = proc_pure_owner_v1918(SLOT, MM_TYPE_PROCESS, SOURCE, WORDS, 0U);
        mach_pi_restore(pi);
        if (result != expected || pi_depth_v1381 ||
            mm_extents[1].span != original.span ||
            mm_extents[1].meta != original.meta)
                return 2;
        return 0;
}

int
main(void)
{
        unsigned int kind;
        int rc;
        for (kind = 1U; kind <= 6U; ++kind) {
                rc = case_v1918(kind);
                if (rc)
                        return (int)(kind * 0100U) + rc;
        }
        for (kind = 1U; kind <= 7U; ++kind) {
                rc = geometry_v1918(kind);
                if (rc)
                        return (int)(01000U + kind * 010U) + rc;
        }
        return 0;
}
