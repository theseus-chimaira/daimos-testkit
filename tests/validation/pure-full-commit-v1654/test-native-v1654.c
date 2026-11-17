/*
 * v1654: FULL transaction MUST NOT publish RESIDENT if either target
 * or original authoritative source cannot be unpinned. Faults here
 * simulate a permanently refused original MM operation, not a media
 * failure. Both variants must preserve TRANSITION and source backing.
 *
 * Compiled into the original native source-linked v1384/v1395 fixture.
 * ANSI C89 only; no production test code or resident DATA.
 */

static int
case_uncertain_v1654(unsigned int kind)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *u = (kword_t *)(unsigned long)UAREA;
        int rc;

        fault_kind_v1395 = 0U;
        fault_calls_v1395 = 0U;
        reset_prefix_v1384();
        if (proc_pure_ram_drop_v1381(SLOT) != MM_OK)
                return 1;
        PROC_SET_TRANSITION(p);
        fault_kind_v1395 = kind;
        rc = proc_pure_ram_restore_v1391(SLOT, accept_payload_v1395);
        if (rc != MM_ERR_BUSY || VM_PDP6_BASE(p) ||
            !PROC_TRANSITION(p) ||
            u[PROC_SWAP_BACKING_OFFSET] != BACKING ||
            proc_swap_records[SLOT].state != BACKING ||
            proc_storage_expect_v30(SLOT, PROC_STORAGE_PACKED) != 0 ||
            !check_suffix_v1384())
                return 2;
        if (kind == 10U) {
                /* Both original RAW and complete temporary APR are
                 * still pinned; no publication, no fabricated retry.
                 * Neither may be freed on an uncertain MM pin state.
                 */
                if (fault_calls_v1395 != 2U ||
                    mm_extent_count != 2 ||
                    MM_EXTENT_BASE(&mm_extents[0]) != SOURCE + OMIT ||
                    MM_EXTENT_WORDS(&mm_extents[0]) != SUFFIX ||
                    MM_EXTENT_TYPE(&mm_extents[0]) !=
                        MM_TYPE_PACKED_PROCESS ||
                    MM_EXTENT_PINNED(&mm_extents[0]) != 1U ||
                    MM_EXTENT_BASE(&mm_extents[1]) != RESTORE ||
                    MM_EXTENT_TYPE(&mm_extents[1]) != MM_TYPE_PROCESS ||
                    MM_EXTENT_WORDS(&mm_extents[1]) != WORDS ||
                    MM_EXTENT_PINNED(&mm_extents[1]) != 1U)
                        return 3;
        } else {
                /* Source unpin failed after successful target unpin.
                 * The unpinned temporary APR must have been freed,
                 * but the uncertain authoritative RAW stays pinned.
                 */
                if (fault_calls_v1395 != 1U ||
                    mm_extent_count != 1 ||
                    MM_EXTENT_BASE(&mm_extents[0]) != SOURCE + OMIT ||
                    MM_EXTENT_WORDS(&mm_extents[0]) != SUFFIX ||
                    MM_EXTENT_TYPE(&mm_extents[0]) !=
                        MM_TYPE_PACKED_PROCESS ||
                    MM_EXTENT_PINNED(&mm_extents[0]) != 1U)
                        return 4;
        }
        return 0;
}

int
main(void)
{
        int rc;

        rc = baseline_main_v1395();
        if (rc != 0)
                return rc;
        rc = case_uncertain_v1654(10U);
        if (rc != 0)
                return 01000 + rc;
        rc = case_uncertain_v1654(11U);
        if (rc != 0)
                return 01100 + rc;
        return 0;
}
