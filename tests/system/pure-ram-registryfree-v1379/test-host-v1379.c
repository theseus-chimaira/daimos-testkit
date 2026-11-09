/*
 * Host verification of the v1379 MM-authoritative PURE-only replacement.
 * Reuse the instrumented v1377 physical-memory fixture, not its old
 * descriptor-registry assertions or production-facing entry points.
 */
#define proc_pure_ram_drop_v1377 proc_pure_ram_drop_v1379
#define proc_pure_ram_restore_v1377 proc_pure_ram_restore_v1379
#define proc_pure_ram_discard_v1377 proc_pure_ram_discard_v1379
#define main retired_fixture_main_v1377
#include "../pure-ram-lifecycle-v1377/test.c"
#undef main
#undef proc_pure_ram_drop_v1377
#undef proc_pure_ram_restore_v1377
#undef proc_pure_ram_discard_v1377

int
proc_storage_expect_v30(unsigned int slot, unsigned int mode)
{
        return proc_storage_get_v28(&proc_storage_runtime_v29, slot) ==
            (int)mode ? 0 : -1;
}

int
proc_storage_publish_v30(unsigned int slot, unsigned int from,
    unsigned int to)
{
        return proc_storage_change_v28(&proc_storage_runtime_v29,
            slot, from, to);
}

void
proc_swap_storage_invariant_v30(void)
{
        assert(!"unexpected storage transition");
}

static void
assert_inactive_v1379(void)
{
        unsigned int i;
        assert(proc_storage_get_v28(&proc_storage_runtime_v29, OWNER) ==
            PROC_STORAGE_PACKED);
        assert(VM_PDP6_BASE(&processes[OWNER]) == 0UL);
        assert(!PROC_TRANSITION(&processes[OWNER]));
        assert(mm_extent_count == 1);
        assert(MM_EXTENT_TYPE(&mm_extents[0]) ==
            MM_TYPE_PACKED_PROCESS);
        assert(MM_EXTENT_OWNER(&mm_extents[0]) == OWNER);
        assert(MM_EXTENT_BASE(&mm_extents[0]) == RAM_BASE);
        assert(MM_EXTENT_WORDS(&mm_extents[0]) == RETAINED);
        assert(!MM_EXTENT_PINNED(&mm_extents[0]));
        assert(!layouts[OWNER]); /* No per-slot layout published or used. */
        assert(ptr(UAREA)[PROC_SWAP_BACKING_OFFSET] == BACKING);
        for (i = 0U; i < RETAINED; ++i)
                assert(ptr(RAM_BASE)[i] ==
                    MUTABLE_PATTERN + (kword_t)(OMIT_WORDS + i));
}

static void
check_registryfree_cycle_v1379(unsigned int format)
{
        unsigned int i;
        setup(format);
        for (i = 0U; i < 3U; ++i) {
                assert(proc_pure_ram_drop_v1379(OWNER) == MM_OK);
                assert_inactive_v1379();
                PROC_SET_TRANSITION(&processes[OWNER]);
                assert(proc_pure_ram_restore_v1379(OWNER, reload) ==
                    MM_OK);
                verify_resident();
                PROC_SET_TRANSITION(&processes[OWNER]);
        }
}

static void
check_registryfree_rollback_v1379(unsigned int format)
{
        setup(format);
        fail_alloc_type = MM_TYPE_PACKED_PROCESS;
        assert(proc_pure_ram_drop_v1379(OWNER) == MM_ERR_NOMEM);
        assert(mm_extent_count == 1);
        assert(!MM_EXTENT_PINNED(&mm_extents[0]));
        fail_alloc_type = -1;

        fail_free_type = MM_TYPE_PROCESS;
        assert(proc_pure_ram_drop_v1379(OWNER) == MM_ERR_BUSY);
        assert(mm_extent_count == 1);
        assert(proc_storage_get_v28(&proc_storage_runtime_v29, OWNER) ==
            PROC_STORAGE_RESIDENT);
        fail_free_type = -1;
        assert(proc_pure_ram_drop_v1379(OWNER) == MM_OK);
        assert_inactive_v1379();
        PROC_SET_TRANSITION(&processes[OWNER]);

        fail_alloc_type = MM_TYPE_PROCESS;
        assert(proc_pure_ram_restore_v1379(OWNER, reload) ==
            MM_ERR_NOMEM);
        assert(mm_extent_count == 1);
        assert(!MM_EXTENT_PINNED(&mm_extents[0]));
        fail_alloc_type = -1;
        fail_reload = 1;
        assert(proc_pure_ram_restore_v1379(OWNER, reload) ==
            MM_ERR_INVAL);
        assert(mm_extent_count == 1);
        assert(!MM_EXTENT_PINNED(&mm_extents[0]));
        fail_reload = 0;
        fail_free_type = MM_TYPE_PACKED_PROCESS;
        assert(proc_pure_ram_restore_v1379(OWNER, reload) ==
            MM_ERR_BUSY);
        assert(mm_extent_count == 1);
        assert(!MM_EXTENT_PINNED(&mm_extents[0]));
        fail_free_type = -1;
        assert(proc_pure_ram_restore_v1379(OWNER, reload) == MM_OK);
        verify_resident();
}

static void
check_registryfree_teardown_v1379(unsigned int format)
{
        setup(format);
        ptr(UAREA)[PROC_CRED_OFFSET] |= PROC_SWAP_MOUNT_EXT_BIT;
        assert(proc_pure_ram_drop_v1379(OWNER) == MM_OK);
        PROC_SET_STATE(&processes[OWNER], PROC_ZOMB);
        PROC_SET_TRANSITION(&processes[OWNER]);
        fail_free_type = MM_TYPE_PACKED_PROCESS;
        assert(proc_pure_ram_discard_v1379(OWNER) == MM_ERR_BUSY);
        assert(mm_extent_count == 1);
        fail_free_type = -1;
        assert(proc_pure_ram_discard_v1379(OWNER) == MM_OK);
        assert(mm_extent_count == 0);
        assert(ptr(UAREA)[PROC_SWAP_BACKING_OFFSET] == 0UL);
        assert(!(ptr(UAREA)[PROC_CRED_OFFSET] &
            PROC_SWAP_MOUNT_EXT_BIT));
        assert(proc_storage_get_v28(&proc_storage_runtime_v29, OWNER) ==
            PROC_STORAGE_RESIDENT);
}

int
main(void)
{
        unsigned int format;
        void *mapped;
        mapped = mmap((void *)0x100000UL, 0x300000UL, PROT_READ |
            PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED, -1, 0);
        assert(mapped == (void *)0x100000UL);
        for (format = PROC_PACKED_LAYOUT_DENSE_V36;
            format <= PROC_PACKED_LAYOUT_SPARSE_V36; ++format) {
                check_registryfree_cycle_v1379(format);
                check_registryfree_rollback_v1379(format);
                check_registryfree_teardown_v1379(format);
        }
        puts("PURE RAM registry-free v1379: cycles/rollback/discard PASS");
        return 0;
}
