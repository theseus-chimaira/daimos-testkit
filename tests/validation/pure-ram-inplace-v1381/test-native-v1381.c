/*
 * PDP-6 v1381: actual assembler MM PURE rebase and KCC transaction.
 * Existing v1377 fixture supplies controlled physical memory and MM
 * alloc/free/pin functions; storage-mode publication uses real PDP-6 ASM.
 */
#include "mm_pure_rebase_v1381.h"

#ifndef NATIVE_BASE_IN_V1384
#define main retired_main_v1379
#define proc_pure_ram_drop_v1379 proc_pure_ram_drop_v1381
#define proc_pure_ram_restore_v1379 proc_pure_ram_restore_v1381
#define proc_pure_ram_discard_v1379 proc_pure_ram_discard_v1381
#define mm_alloc_aligned_noreclaim mm_alloc_fixture_v1381
#define mm_free mm_free_fixture_v1381
#include "test-native-v1379.c"
#undef main
#undef proc_pure_ram_drop_v1379
#undef proc_pure_ram_restore_v1379
#undef proc_pure_ram_discard_v1379
#undef mm_alloc_aligned_noreclaim
#undef mm_free
#endif

static unsigned int pi_depth_v1381;
static unsigned int pi_disable_count_v1381;
static unsigned int pi_restore_count_v1381;
static unsigned int alloc_count_v1381;
static unsigned int free_count_v1381;

kword_t
mach_pi_disable(void)
{
        if (pi_depth_v1381)
                __test_exit = 076UL;
        ++pi_depth_v1381;
        ++pi_disable_count_v1381;
        return 0200UL;
}

void
mach_pi_restore(kword_t saved)
{
        if (pi_depth_v1381 != 1U || saved != 0200UL)
                __test_exit = 075UL;
        --pi_depth_v1381;
        ++pi_restore_count_v1381;
}

int
mm_alloc_aligned_noreclaim(kword_t words, kword_t align,
    unsigned int type, unsigned int owner, unsigned int preference,
    kword_t *basep)
{
        ++alloc_count_v1381;
        return mm_alloc_fixture_v1381(words, align, type, owner,
            preference, basep);
}

int
mm_free(kword_t base, unsigned int type, unsigned int owner)
{
        ++free_count_v1381;
        return mm_free_fixture_v1381(base, type, owner);
}

static int
check_no_mutation_v1381(kword_t old_span, kword_t old_meta)
{
        return mm_extents[0].span == old_span &&
            mm_extents[0].meta == old_meta;
}

static int
bad_inputs_v1381(void)
{
        kword_t old_span, old_meta;
        int rc;
        mm_extent_count = 0;
        add_extent(SOURCE, WORDS, MM_TYPE_PROCESS);
        old_span = mm_extents[0].span;
        if (mm_pin(SOURCE) != MM_OK)
                return 1;
        old_meta = mm_extents[0].meta;

        rc = mm_pure_rebase_pinned_v1381(SOURCE, SLOT + 1U, OMIT, WORDS);
        if (rc != MM_ERR_INVAL ||
            !check_no_mutation_v1381(old_span, old_meta))
                return 2;
        rc = mm_pure_rebase_pinned_v1381(SOURCE, SLOT, OMIT + 1U, WORDS);
        if (rc != MM_ERR_INVAL ||
            !check_no_mutation_v1381(old_span, old_meta))
                return 3;
        rc = mm_pure_rebase_pinned_v1381(SOURCE, SLOT, OMIT, WORDS + 1UL);
        if (rc != MM_ERR_INVAL ||
            !check_no_mutation_v1381(old_span, old_meta))
                return 4;
        rc = mm_pure_rebase_pinned_v1381(SOURCE, SLOT, WORDS, WORDS);
        if (rc != MM_ERR_INVAL ||
            !check_no_mutation_v1381(old_span, old_meta))
                return 5;
        mm_extents[0].meta = (old_meta &
            ~((kword_t)MM_TYPE_MASK << MM_TYPE_SHIFT)) |
            ((kword_t)MM_TYPE_KERNEL_DYNAMIC << MM_TYPE_SHIFT);
        old_meta = mm_extents[0].meta;
        rc = mm_pure_rebase_pinned_v1381(SOURCE, SLOT, OMIT, WORDS);
        if (rc != MM_ERR_INVAL ||
            !check_no_mutation_v1381(old_span, old_meta))
                return 9;
        mm_extents[0].meta = (old_meta &
            ~((kword_t)MM_TYPE_MASK << MM_TYPE_SHIFT)) |
            ((kword_t)MM_TYPE_PROCESS << MM_TYPE_SHIFT);
        if (mm_pin(SOURCE) != MM_OK)
                return 6;
        old_meta = mm_extents[0].meta;
        rc = mm_pure_rebase_pinned_v1381(SOURCE, SLOT, OMIT, WORDS);
        if (rc != MM_ERR_BUSY ||
            !check_no_mutation_v1381(old_span, old_meta))
                return 7;
        if (mm_unpin(SOURCE) != MM_OK ||
            mm_unpin(SOURCE) != MM_OK)
                return 8;

        /*
         * The top managed physical address is 01000000 octal (one past
         * the 18-bit address range), NOT 0400000. Verify both boundary
         * acceptance and one-word-overflow rejection against actual ASM.
         */
        mm_extents[0].span = (WORDS << 18U) | 0776000UL;
        mm_extents[0].meta = ((kword_t)MM_TYPE_PROCESS <<
            MM_TYPE_SHIFT) | SLOT |
            ((kword_t)1UL << MM_PIN_SHIFT);
        rc = mm_pure_rebase_pinned_v1381(0776000UL, SLOT, OMIT, WORDS);
        if (rc != MM_OK ||
            MM_EXTENT_BASE(&mm_extents[0]) != 0776400UL ||
            MM_EXTENT_WORDS(&mm_extents[0]) != SUFFIX ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PACKED_PROCESS)
                return 10;
        mm_extents[0].span = ((WORDS + 02000UL) << 18U) | 0776000UL;
        mm_extents[0].meta = ((kword_t)MM_TYPE_PROCESS <<
            MM_TYPE_SHIFT) | SLOT |
            ((kword_t)1UL << MM_PIN_SHIFT);
        old_span = mm_extents[0].span;
        old_meta = mm_extents[0].meta;
        rc = mm_pure_rebase_pinned_v1381(0776000UL, SLOT, OMIT,
            WORDS + 02000UL);
        if (rc != MM_ERR_INVAL ||
            !check_no_mutation_v1381(old_span, old_meta))
                return 11;
        return 0;
}

#ifndef NATIVE_NO_MAIN_V1384
int
main(void)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *source = (kword_t *)(unsigned long)SOURCE;
        kword_t *suffix = (kword_t *)(unsigned long)(SOURCE + OMIT);
        kword_t *dest = (kword_t *)(unsigned long)RESTORE;
        kword_t *uarea = (kword_t *)(unsigned long)UAREA;
        unsigned int i;
        int rc = bad_inputs_v1381();

        if (rc)
                return 0100 + rc;
        mm_extent_count = 0;
        add_extent(SOURCE, WORDS, MM_TYPE_PROCESS);
        for (i = 0U; i < PROC_UAREA_WORDS; ++i)
                uarea[i] = 0UL;
        for (i = 0U; i < WORDS; ++i)
                source[i] = i < OMIT ? TEXT_PATTERN : PATTERN + i;
        for (i = 0U; i < PROC_STORAGE_MAP_WORDS_V28(SLOTS); ++i)
                mode_words[i] = 0UL;
        proc_storage_runtime_v29.words = mode_words;
        proc_storage_runtime_v29.slots = SLOTS;
        p->meta = (UAREA << PROC_HALF_SHIFT) |
            ((kword_t)(PROC_F_UAREA | PROC_F_TRANSITION) <<
                PROC_FLAGS_SHIFT);
        p->vm_state = (WORDS << PROC_HALF_SHIFT) | SOURCE;
        p->sched = (kword_t)PROC_SLEEP << PROC_STATE_SHIFT;
        swap_slots[SLOT].state = BACKING;
        pi_depth_v1381 = 0U;
        pi_disable_count_v1381 = 0U;
        pi_restore_count_v1381 = 0U;
        alloc_count_v1381 = 0U;
        free_count_v1381 = 0U;

        if (proc_pure_ram_drop_v1381(SLOT) != MM_OK)
                return 1;
        if (alloc_count_v1381 || free_count_v1381 ||
            pi_depth_v1381 || pi_disable_count_v1381 != 1U ||
            pi_restore_count_v1381 != 1U)
                return 2;
        if (VM_PDP6_BASE(p) || mm_extent_count != 1 ||
            MM_EXTENT_BASE(&mm_extents[0]) != SOURCE + OMIT ||
            MM_EXTENT_WORDS(&mm_extents[0]) != SUFFIX ||
            MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PACKED_PROCESS ||
            MM_EXTENT_OWNER(&mm_extents[0]) != SLOT ||
            MM_EXTENT_PINNED(&mm_extents[0]) ||
            uarea[PROC_SWAP_BACKING_OFFSET] != BACKING ||
            PROC_TRANSITION(p))
                return 3;
        for (i = 0U; i < SUFFIX; ++i)
                if (suffix[i] != PATTERN + OMIT + i)
                        return 4;
        PROC_SET_TRANSITION(p);
        refuse_restore_alloc = 1;
        if (proc_pure_ram_restore_v1381(SLOT, reload) != MM_ERR_NOMEM ||
            mm_extent_count != 1 || MM_EXTENT_PINNED(&mm_extents[0]))
                return 5;
        refuse_restore_alloc = 0;
        if (proc_pure_ram_restore_v1381(SLOT, reload) != MM_OK)
                return 6;
        if (VM_PDP6_BASE(p) != RESTORE || mm_extent_count != 1 ||
            proc_storage_expect_v30(SLOT, PROC_STORAGE_RESIDENT) != 0 ||
            PROC_TRANSITION(p))
                return 7;
        for (i = 020U; i < WORDS; ++i)
                if (dest[i] !=
                    (i < OMIT ? TEXT_PATTERN : PATTERN + i))
                        return 8;
        PROC_SET_TRANSITION(p);
        if (proc_pure_ram_drop_v1381(SLOT) != MM_OK ||
            MM_EXTENT_BASE(&mm_extents[0]) != RESTORE + OMIT ||
            pi_disable_count_v1381 != 2U ||
            pi_restore_count_v1381 != 2U)
                return 9;
        PROC_SET_STATE(p, PROC_ZOMB);
        PROC_SET_TRANSITION(p);
        uarea[PROC_CRED_OFFSET] |= PROC_SWAP_MOUNT_EXT_BIT;
        if (proc_pure_ram_discard_v1381(SLOT) != MM_OK ||
            mm_extent_count != 0 ||
            swap_slots[SLOT].state != 0UL ||
            uarea[PROC_SWAP_BACKING_OFFSET] != 0UL ||
            (uarea[PROC_CRED_OFFSET] & PROC_SWAP_MOUNT_EXT_BIT))
                return 10;
        return 0;
}
#endif
