/*
 * Native PDP-6 verification of the compact v1379 PURE-only transaction.
 * Reuses the v1377 physical-memory fixture but links real existing
 * assembler storage-mode operations, with NO packed layout/registry code.
 */
#define DAIMOS_TEST_FIXTURE_NO_MAIN 1
#define proc_pure_ram_drop_v1377 proc_pure_ram_drop_v1379
#define proc_pure_ram_restore_v1377 proc_pure_ram_restore_v1379
#define proc_pure_ram_discard_v1377 proc_pure_ram_discard_v1379
#include "test-native-v1377.c"
#undef proc_pure_ram_drop_v1377
#undef proc_pure_ram_restore_v1377
#undef proc_pure_ram_discard_v1377

extern int proc_storage_expect_v30(unsigned int, unsigned int);

void
proc_swap_storage_invariant_v30(void)
{
        __test_exit = 077UL;
}

/*
 * The source fixture MM backend rejects a second allocation on a live
 * owner. The v1379 test additionally injects precise source free and
 * restore allocation errors via source-specific flags.
 */
int
main(void)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *source = (kword_t *)(unsigned long)SOURCE;
        kword_t *saved = (kword_t *)(unsigned long)PACKED;
        kword_t *dest = (kword_t *)(unsigned long)RESTORE;
        kword_t *uarea = (kword_t *)(unsigned long)UAREA;
        unsigned int i;
        unsigned int j;

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

        /* The raw suffix's owner/size comes from MM, not a registry. */
        for (j = 0U; j < 3U; ++j) {
                if (proc_pure_ram_drop_v1379(SLOT) != MM_OK)
                        return 1;
                if (VM_PDP6_BASE(p) || mm_extent_count != 1 ||
                    MM_EXTENT_BASE(&mm_extents[0]) != PACKED ||
                    MM_EXTENT_WORDS(&mm_extents[0]) != SUFFIX ||
                    MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PACKED_PROCESS ||
                    PROC_TRANSITION(p) ||
                    uarea[PROC_SWAP_BACKING_OFFSET] != BACKING)
                        return 2;
                for (i = 0U; i < SUFFIX; ++i)
                        if (saved[i] != PATTERN + OMIT + i)
                                return 3;
                PROC_SET_TRANSITION(p);
                refuse_restore_alloc = 1;
                if (proc_pure_ram_restore_v1379(SLOT, reload) !=
                    MM_ERR_NOMEM || mm_extent_count != 1 ||
                    MM_EXTENT_PINNED(&mm_extents[0]))
                        return 4;
                refuse_restore_alloc = 0;
                if (proc_pure_ram_restore_v1379(SLOT, reload) != MM_OK)
                        return 5;
                if (VM_PDP6_BASE(p) != RESTORE || mm_extent_count != 1 ||
                    PROC_TRANSITION(p) ||
                    proc_storage_expect_v30(SLOT,
                        PROC_STORAGE_RESIDENT) != 0)
                        return 6;
                for (i = 020U; i < WORDS; ++i)
                        if (dest[i] !=
                            (i < OMIT ? TEXT_PATTERN : PATTERN + i))
                                return 7;
                PROC_SET_TRANSITION(p);
        }
        if (proc_pure_ram_drop_v1379(SLOT) != MM_OK)
                return 8;
        PROC_SET_STATE(p, PROC_ZOMB);
        PROC_SET_TRANSITION(p);
        uarea[PROC_CRED_OFFSET] |= PROC_SWAP_MOUNT_EXT_BIT;
        if (proc_pure_ram_discard_v1379(SLOT) != MM_OK ||
            mm_extent_count != 0 || swap_slots[SLOT].state != 0UL ||
            uarea[PROC_SWAP_BACKING_OFFSET] != 0UL ||
            (uarea[PROC_CRED_OFFSET] & PROC_SWAP_MOUNT_EXT_BIT))
                return 9;
        return 0;
}
