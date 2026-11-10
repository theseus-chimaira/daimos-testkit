/*
 * Host validation of the exact v1381 transaction with a faithful
 * owner-checked model of the staged PDP-6 rebase primitive.
 *
 * The old v1377 test fixture supplies isolated physical memory, a real
 * sorted MM descriptor array, typed MM allocation and failure injection.
 * No helper storage registry is consulted by the new implementation.
 */
#define proc_pure_ram_drop_v1377 proc_pure_ram_drop_v1381
#define proc_pure_ram_restore_v1377 proc_pure_ram_restore_v1381
#define proc_pure_ram_discard_v1377 proc_pure_ram_discard_v1381
#define main retired_main_v1377
#include "../pure-ram-lifecycle-v1377/test.c"
#undef main
#undef proc_pure_ram_drop_v1377
#undef proc_pure_ram_restore_v1377
#undef proc_pure_ram_discard_v1377

static unsigned int pi_depth_v1381;
static unsigned int pi_saves_v1381;
static unsigned int pi_restores_v1381;
static unsigned int rebase_calls_v1381;
static int refuse_rebase_v1381;

int
proc_storage_expect_v30(unsigned int slot, unsigned int state)
{
        return proc_storage_get_v28(&proc_storage_runtime_v29, slot) ==
            (int)state ? 0 : -1;
}

int
proc_storage_publish_v30(unsigned int slot, unsigned int old_state,
    unsigned int new_state)
{
        assert(pi_depth_v1381 == 1U ||
            (old_state == PROC_STORAGE_PACKED &&
            new_state == PROC_STORAGE_RESIDENT));
        return proc_storage_change_v28(&proc_storage_runtime_v29, slot,
            old_state, new_state);
}

void
proc_swap_storage_invariant_v30(void)
{
        assert(!"unexpected two-bit storage transition");
}

kword_t
mach_pi_disable(void)
{
        assert(pi_depth_v1381 == 0U);
        ++pi_depth_v1381;
        ++pi_saves_v1381;
        return 0200UL;
}

void
mach_pi_restore(kword_t saved)
{
        assert(pi_depth_v1381 == 1U);
        assert(saved == 0200UL);
        --pi_depth_v1381;
        ++pi_restores_v1381;
}

int
mm_pure_rebase_pinned_v1381(kword_t base, unsigned int owner,
    kword_t prefix, kword_t original)
{
        struct mm_extent *e;
        int i = find_extent(base);

        ++rebase_calls_v1381;
        assert(pi_depth_v1381 == 1U);
        if (refuse_rebase_v1381 || i < 0 || !owner || owner > 0377U ||
            !base || (base & 01777UL) || !prefix ||
            (prefix & 0177UL) || !original ||
            (original & 01777UL) || prefix >= original ||
            base + original > 01000000UL)
                return MM_ERR_INVAL;
        e = &mm_extents[i];
        if (MM_EXTENT_TYPE(e) != MM_TYPE_PROCESS ||
            MM_EXTENT_OWNER(e) != owner ||
            MM_EXTENT_WORDS(e) != original)
                return MM_ERR_INVAL;
        if (MM_EXTENT_PINS(e) != 1U)
                return MM_ERR_BUSY;
        e->span = ((original - prefix) << 18U) | (base + prefix);
        e->meta = (e->meta & ~((kword_t)MM_TYPE_MASK <<
            MM_TYPE_SHIFT)) |
            ((kword_t)MM_TYPE_PACKED_PROCESS << MM_TYPE_SHIFT);
        return MM_OK;
}

static void
assert_inactive_v1381(kword_t original)
{
        unsigned int i;
        kword_t suffix = original + OMIT_WORDS;
        assert(proc_storage_expect_v30(OWNER, PROC_STORAGE_PACKED) == 0);
        assert(VM_PDP6_BASE(&processes[OWNER]) == 0UL);
        assert(!PROC_TRANSITION(&processes[OWNER]));
        assert(mm_extent_count == 1);
        assert(MM_EXTENT_TYPE(&mm_extents[0]) ==
            MM_TYPE_PACKED_PROCESS);
        assert(MM_EXTENT_BASE(&mm_extents[0]) == suffix);
        assert(MM_EXTENT_WORDS(&mm_extents[0]) == RETAINED);
        assert(MM_EXTENT_OWNER(&mm_extents[0]) == OWNER);
        assert(!MM_EXTENT_PINNED(&mm_extents[0]));
        assert(ptr(UAREA)[PROC_SWAP_BACKING_OFFSET] == BACKING);
        assert(!layouts[OWNER]);
        for (i = 0U; i < RETAINED; ++i)
                assert(ptr(suffix)[i] ==
                    MUTABLE_PATTERN + (kword_t)(OMIT_WORDS + i));
}

static void
assert_resident_v1381(void)
{
        unsigned int i;
        kword_t base = VM_PDP6_BASE(&processes[OWNER]);
        kword_t *image = ptr(base);
        assert(proc_storage_expect_v30(OWNER, PROC_STORAGE_RESIDENT) == 0);
        assert(mm_extent_count == 1);
        for (i = 020U; i < FULL_WORDS; ++i) {
                kword_t wanted = i < OMIT_WORDS ? PURE_PATTERN :
                    MUTABLE_PATTERN + (kword_t)i;
                if (image[i] != wanted)
                        fprintf(stderr,
                            "v1381 mismatch: base=%lo i=%o got=%lo expected=%lo\n",
                            (unsigned long)base, i,
                            (unsigned long)image[i], (unsigned long)wanted);
                assert(image[i] == wanted);
        }
}

static void
test_inplace_cycles_v1381(unsigned int format)
{
        unsigned int i;
        kword_t base = PHYS_A;
        setup(format);
        pi_depth_v1381 = 0U;
        pi_saves_v1381 = pi_restores_v1381 = 0U;
        rebase_calls_v1381 = 0U;
        for (i = 0U; i < 3U; ++i) {
                unsigned int alloc_before = alloc_calls;
                unsigned int free_before = free_calls;
                assert(VM_PDP6_BASE(&processes[OWNER]) == base);
                assert(proc_pure_ram_drop_v1381(OWNER) == MM_OK);
                assert(alloc_calls == alloc_before);
                assert(free_calls == free_before);
                assert_inactive_v1381(base);
                assert(pi_depth_v1381 == 0U);
                PROC_SET_TRANSITION(&processes[OWNER]);
                assert(proc_pure_ram_restore_v1381(OWNER, reload) ==
                    MM_OK);
                assert_resident_v1381();
                base = VM_PDP6_BASE(&processes[OWNER]);
                PROC_SET_TRANSITION(&processes[OWNER]);
        }
        assert(rebase_calls_v1381 == 3U);
        assert(pi_saves_v1381 == 3U && pi_restores_v1381 == 3U);
}

static void
test_inplace_failures_v1381(unsigned int format)
{
        unsigned int saves;
        setup(format);
        pi_depth_v1381 = 0U;
        refuse_rebase_v1381 = 1;
        saves = pi_saves_v1381;
        assert(proc_pure_ram_drop_v1381(OWNER) == MM_ERR_INVAL);
        assert(pi_depth_v1381 == 0U);
        assert(pi_saves_v1381 == saves + 1U);
        assert(pi_restores_v1381 == pi_saves_v1381);
        assert(mm_extent_count == 1);
        assert(MM_EXTENT_BASE(&mm_extents[0]) == PHYS_A);
        assert(MM_EXTENT_WORDS(&mm_extents[0]) == FULL_WORDS);
        assert(MM_EXTENT_TYPE(&mm_extents[0]) == MM_TYPE_PROCESS);
        assert(!MM_EXTENT_PINNED(&mm_extents[0]));
        assert(proc_storage_expect_v30(OWNER, PROC_STORAGE_RESIDENT) ==
            0);
        refuse_rebase_v1381 = 0;

        fail_pin_type = MM_TYPE_PROCESS;
        assert(proc_pure_ram_drop_v1381(OWNER) == MM_ERR_BUSY);
        fail_pin_type = -1;
        assert(mm_extent_count == 1);
        assert(!MM_EXTENT_PINNED(&mm_extents[0]));

        assert(proc_pure_ram_drop_v1381(OWNER) == MM_OK);
        assert_inactive_v1381(PHYS_A);
        PROC_SET_TRANSITION(&processes[OWNER]);
        fail_alloc_type = MM_TYPE_PROCESS;
        assert(proc_pure_ram_restore_v1381(OWNER, reload) ==
            MM_ERR_NOMEM);
        assert(mm_extent_count == 1);
        assert(!MM_EXTENT_PINNED(&mm_extents[0]));
        fail_alloc_type = -1;
        fail_reload = 1;
        assert(proc_pure_ram_restore_v1381(OWNER, reload) ==
            MM_ERR_INVAL);
        fail_reload = 0;
        assert(proc_pure_ram_restore_v1381(OWNER, reload) == MM_OK);
        assert_resident_v1381();
}

static void
test_inplace_discard_v1381(unsigned int format)
{
        setup(format);
        pi_depth_v1381 = 0U;
        ptr(UAREA)[PROC_CRED_OFFSET] |= PROC_SWAP_MOUNT_EXT_BIT;
        assert(proc_pure_ram_drop_v1381(OWNER) == MM_OK);
        PROC_SET_STATE(&processes[OWNER], PROC_ZOMB);
        PROC_SET_TRANSITION(&processes[OWNER]);
        assert(proc_pure_ram_discard_v1381(OWNER) == MM_OK);
        assert(mm_extent_count == 0);
        assert(ptr(UAREA)[PROC_SWAP_BACKING_OFFSET] == 0UL);
        assert(!(ptr(UAREA)[PROC_CRED_OFFSET] &
            PROC_SWAP_MOUNT_EXT_BIT));
}

#ifndef DAIMOS_TEST_FIXTURE_NO_MAIN_V1384
int
main(void)
{
        unsigned int format;
        void *mapped = mmap((void *)0x100000UL, 0x300000UL,
            PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS |
            MAP_FIXED, -1, 0);
        assert(mapped == (void *)0x100000UL);
        for (format = PROC_PACKED_LAYOUT_DENSE_V36;
            format <= PROC_PACKED_LAYOUT_SPARSE_V36; ++format) {
                test_inplace_cycles_v1381(format);
                test_inplace_failures_v1381(format);
                test_inplace_discard_v1381(format);
        }
        puts("PURE RAM v1381 zero-copy: cycles/PI/rollback/discard PASS");
        return 0;
}
#endif
