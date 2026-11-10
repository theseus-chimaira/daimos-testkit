/*
 * C89 host tests of the actual v1384 process transaction and an exact
 * reference model of its owner-checked MM reserve/release/commit API.
 * Older v1381 fixtures supply MM pins, typed allocator and real 36-bit
 * process state. No new production kernel object is linked.
 */
#define DAIMOS_TEST_FIXTURE_NO_MAIN_V1384 1
#include "../pure-ram-inplace-v1381/test-host-v1381.c"

#include "proc_pure_restore_v1384.h"
#include "exec.h"

static unsigned int reserve_calls_v1384;
static unsigned int release_calls_v1384;
static unsigned int commit_calls_v1384;
static unsigned int prefix_calls_v1384;
static unsigned int prefix_failure_v1384;

static void
arena_v1384(void)
{
        mm_arena_count = 1;
        mm_arenas[0] = ((kword_t)0x18000UL << 18U) | 0x20000UL;
}

static int
mm_prefix_model_v1384(kword_t argument, unsigned int owner,
    kword_t prefix, kword_t full, unsigned int operation)
{
        kword_t suffix, original, length;
        int i, found = -1;
        struct mm_extent *e;

        assert(pi_depth_v1381 == 1U);
        if (!owner || owner > 0377U || !argument || !prefix ||
            (prefix & 0177UL) || !full || (full & 01777UL) ||
            prefix >= full)
                return MM_ERR_INVAL;
        suffix = operation == 0U ? argument : argument + prefix;
        if (suffix < prefix)
                return MM_ERR_INVAL;
        original = suffix - prefix;
        length = full - prefix;
        if ((original & 01777UL) || original + full > 01000000UL)
                return MM_ERR_INVAL;
        for (i = 0; i < mm_extent_count; ++i)
                if (MM_EXTENT_BASE(&mm_extents[i]) ==
                    (operation == 0U ? suffix : original)) {
                        found = i;
                        break;
                }
        if (found < 0)
                return MM_ERR_INVAL;
        e = &mm_extents[found];
        if (MM_EXTENT_TYPE(e) != MM_TYPE_PACKED_PROCESS ||
            MM_EXTENT_OWNER(e) != owner ||
            MM_EXTENT_WORDS(e) != (operation == 0U ? length : full))
                return MM_ERR_INVAL;
        if (MM_EXTENT_PINS(e) != 1U)
                return MM_ERR_BUSY;
        if (operation == 0U) {
                kword_t end = original + full;
                unsigned int in_arena = 0U;
                if (found > 0 &&
                    MM_EXTENT_BASE(&mm_extents[found - 1]) +
                    MM_EXTENT_WORDS(&mm_extents[found - 1]) > original)
                        return MM_ERR_FRAGMENTED;
                for (i = 0; i < mm_arena_count; ++i)
                    if (MM_ARENA_BASE(mm_arenas[i]) <= original &&
                        MM_ARENA_BASE(mm_arenas[i]) +
                        MM_ARENA_WORDS(mm_arenas[i]) >= end)
                        in_arena = 1U;
                if (!in_arena)
                        return MM_ERR_FRAGMENTED;
                e->span = (full << 18U) | original;
        } else if (operation == 1U) {
                e->span = (length << 18U) | suffix;
        } else {
                e->meta = (e->meta & ~((kword_t)MM_TYPE_MASK <<
                    MM_TYPE_SHIFT)) |
                    ((kword_t)MM_TYPE_PROCESS << MM_TYPE_SHIFT);
        }
        return MM_OK;
}

int
mm_pure_claim_prefix_v1384(kword_t suffix, unsigned int owner,
    kword_t prefix, kword_t full)
{
        ++reserve_calls_v1384;
        return mm_prefix_model_v1384(suffix, owner, prefix, full, 0U);
}

int
mm_pure_release_prefix_v1384(kword_t base, unsigned int owner,
    kword_t prefix, kword_t full)
{
        ++release_calls_v1384;
        return mm_prefix_model_v1384(base, owner, prefix, full, 1U);
}

int
mm_pure_commit_prefix_v1384(kword_t base, unsigned int owner,
    kword_t prefix, kword_t full)
{
        ++commit_calls_v1384;
        return mm_prefix_model_v1384(base, owner, prefix, full, 2U);
}

/* Plain DXR would read only the reconstructible prefix from an immutable
 * provider. The mock rejects an unsupported compression format before
 * touching user memory; the committed callback cannot write into suffix.
 */
static int
reload_prefix_v1384(kword_t backing, kword_t base, kword_t uarea,
    kword_t prefix)
{
        unsigned int i;
        kword_t *target = ptr(base);
        ++prefix_calls_v1384;
        assert(pi_depth_v1381 == 0U);
        assert(backing == BACKING && uarea == UAREA);
        assert(prefix == OMIT_WORDS);
        if (prefix_failure_v1384 == 2U)
                return -2;  /* compressed DXR: use full restore */
        for (i = EXEC_USER_ORIGIN; i < prefix; ++i) {
                target[i] = PURE_PATTERN;
                if (prefix_failure_v1384 == 1U && i > 030U)
                        return -1;
        }
        return 0;
}

static void
reset_v1384(unsigned int format)
{
        setup(format);
        arena_v1384();
        pi_depth_v1381 = 0U;
        reserve_calls_v1384 = release_calls_v1384 = 0U;
        commit_calls_v1384 = prefix_calls_v1384 = 0U;
        prefix_failure_v1384 = 0U;
}

static void
verify_suffix_v1384(kword_t saved_base)
{
        unsigned int i;
        const kword_t *suffix = ptr(saved_base + OMIT_WORDS);
        for (i = 0U; i < RETAINED; ++i)
                assert(suffix[i] == MUTABLE_PATTERN +
                    (kword_t)(OMIT_WORDS + i));
}

static void
test_fast_v1384(unsigned int format)
{
        unsigned int a, f;
        reset_v1384(format);
        assert(proc_pure_ram_drop_v1381(OWNER) == MM_OK);
        a = alloc_calls;
        f = free_calls;
        PROC_SET_TRANSITION(&processes[OWNER]);
        assert(proc_pure_restore_v1384(OWNER,
            reload_prefix_v1384) == MM_OK);
        assert(alloc_calls == a && free_calls == f);
        assert(VM_PDP6_BASE(&processes[OWNER]) == PHYS_A);
        assert_resident_v1381();
        assert(!PROC_TRANSITION(&processes[OWNER]));
        assert(pi_depth_v1381 == 0U);
        assert(reserve_calls_v1384 == 1U &&
            commit_calls_v1384 == 1U && !release_calls_v1384);
        assert(prefix_calls_v1384 == 1U);
}

static void
test_abort_v1384(unsigned int format, unsigned int code)
{
        reset_v1384(format);
        assert(proc_pure_ram_drop_v1381(OWNER) == MM_OK);
        PROC_SET_TRANSITION(&processes[OWNER]);
        prefix_failure_v1384 = code;
        assert(proc_pure_restore_v1384(OWNER,
            reload_prefix_v1384) == (code == 2U ?
                PROC_PURE_PREFIX_FALLBACK_V1384 : MM_ERR_INVAL));
        assert(mm_extent_count == 1);
        assert(MM_EXTENT_BASE(&mm_extents[0]) == PHYS_A + OMIT_WORDS);
        assert(MM_EXTENT_WORDS(&mm_extents[0]) == RETAINED);
        assert(MM_EXTENT_TYPE(&mm_extents[0]) ==
            MM_TYPE_PACKED_PROCESS);
        assert(!MM_EXTENT_PINNED(&mm_extents[0]));
        assert(proc_storage_expect_v30(OWNER, PROC_STORAGE_PACKED) == 0);
        assert(VM_PDP6_BASE(&processes[OWNER]) == 0UL);
        assert(pi_depth_v1381 == 0U);
        assert(PROC_TRANSITION(&processes[OWNER]));
        verify_suffix_v1384(PHYS_A);
        assert(release_calls_v1384 == 1U);
        prefix_failure_v1384 = 0U;
        assert(proc_pure_restore_v1384(OWNER,
            reload_prefix_v1384) == MM_OK);
        assert_resident_v1381();
}

static void
test_occupied_v1384(unsigned int format)
{
        struct mm_extent blocker, saved;
        reset_v1384(format);
        assert(proc_pure_ram_drop_v1381(OWNER) == MM_OK);
        PROC_SET_TRANSITION(&processes[OWNER]);
        blocker.span = ((kword_t)0200UL << 18U) | PHYS_A;
        blocker.meta = ((kword_t)MM_TYPE_KERNEL_DYNAMIC <<
            MM_TYPE_SHIFT) | 7UL;
        saved = mm_extents[0];
        mm_extents[1] = saved;
        mm_extents[0] = blocker;
        mm_extent_count = 2;
        assert(proc_pure_restore_v1384(OWNER,
            reload_prefix_v1384) ==
            PROC_PURE_PREFIX_FALLBACK_V1384);
        assert(!prefix_calls_v1384);
        assert(mm_extent_count == 2);
        assert(MM_EXTENT_BASE(&mm_extents[1]) == PHYS_A + OMIT_WORDS);
        assert(!MM_EXTENT_PINNED(&mm_extents[1]));
        assert(pi_depth_v1381 == 0U);
        verify_suffix_v1384(PHYS_A);

        /* The full-extent fallback can choose a disjoint APR allocation,
         * with the immutable suffix remaining valid until the copy.
         */
        assert(proc_pure_ram_restore_v1381(OWNER, reload) == MM_OK);
        assert(VM_PDP6_BASE(&processes[OWNER]) == PHYS_B);
        assert(mm_extent_count == 2);
        assert(proc_storage_expect_v30(OWNER, PROC_STORAGE_RESIDENT) == 0);
        {
                unsigned int i;
                kword_t *restored = ptr(PHYS_B);
                for (i = EXEC_USER_ORIGIN; i < FULL_WORDS; ++i)
                        assert(restored[i] == (i < OMIT_WORDS ?
                            PURE_PATTERN : MUTABLE_PATTERN + (kword_t)i));
        }
}

static void
test_unmanaged_v1384(unsigned int format)
{
        reset_v1384(format);
        assert(proc_pure_ram_drop_v1381(OWNER) == MM_OK);
        PROC_SET_TRANSITION(&processes[OWNER]);
        mm_arenas[0] = ((kword_t)0x1000UL << 18U) |
            (PHYS_A + OMIT_WORDS);
        assert(proc_pure_restore_v1384(OWNER,
            reload_prefix_v1384) ==
            PROC_PURE_PREFIX_FALLBACK_V1384);
        assert(!prefix_calls_v1384);
        verify_suffix_v1384(PHYS_A);
}

int
main(void)
{
        unsigned int format;
        void *mapped = mmap((void *)0x100000UL, 0x300000UL,
            PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS |
            MAP_FIXED, -1, 0);
    assert(mapped == (void *)0x100000UL);
    test_inplace_cycles_v1381(PROC_PACKED_LAYOUT_DENSE_V36);
    test_inplace_failures_v1381(PROC_PACKED_LAYOUT_DENSE_V36);
    test_inplace_discard_v1381(PROC_PACKED_LAYOUT_DENSE_V36);
    for (format = PROC_PACKED_LAYOUT_DENSE_V36;
            format <= PROC_PACKED_LAYOUT_SPARSE_V36; ++format) {
                test_fast_v1384(format);
                test_abort_v1384(format, 1U);
                test_abort_v1384(format, 2U);
                test_occupied_v1384(format);
                test_unmanaged_v1384(format);
        }
        puts("PURE prefix v1384: in-place/rollback/fallback PASS");
        return 0;
}
