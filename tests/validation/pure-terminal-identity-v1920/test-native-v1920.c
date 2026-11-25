/* Current terminal contract: reconcile transactions before destruction. */
static int
terminal_case_v1920(unsigned int kind)
{
        struct proc *p = &process_v1609[V1609_SLOT];
        kword_t *u = (kword_t *)(unsigned long)V1609_UAREA;
        kword_t marker, expected_marker, span, meta;
        int count;

        prepare_v1609();
        terminal_fault_v1920 = 0U;
        switch (kind) {
        case 1U: /* A size-matched scratch is not proof of identity. */
                add_extent_v1609(060000UL, V1609_WORDS, MM_TYPE_PROCESS,
                    V1609_SLOT, 0U);
                break;
        case 2U:
                u[PROC_FINALIZE_OFFSET] = PROC_PURE_FULL_ESCROW_V1917(
                    V1609_BASE, 060000UL);
                break;
        case 3U:
                u[PROC_FINALIZE_OFFSET] = PROC_PURE_INPLACE_ESCROW_V1919(
                    V1609_BASE, PROC_PURE_DROP_TAG_V1919);
                break;
        case 4U:
                u[PROC_FINALIZE_OFFSET] = PROC_PURE_INPLACE_ESCROW_V1919(
                    V1609_BASE, PROC_PURE_PREFIX_TAG_V1919);
                break;
        case 5U: /* Wrong aligned origin. */
                ++mm_extents[0].span;
                break;
        case 6U: /* Preceding overlapping foreign module. */
                mm_extents[1] = mm_extents[0];
                mm_extent_count = 2;
                mm_extents[0].span = (01000UL << 18U) | 050000UL;
                mm_extents[0].meta = ((kword_t)MM_TYPE_MODULE << MM_TYPE_SHIFT) | 2U;
                break;
        case 7U:
                add_extent_v1609(051000UL, 0200UL, MM_TYPE_KERNEL_DYNAMIC,
                    V1609_SLOT, 0U);
                break;
        case 8U:
                add_extent_v1609(060000UL, 0UL, MM_TYPE_MODULE, 2U, 0U);
                break;
        case 9U:
                add_extent_v1609(0777600UL, 0400UL, MM_TYPE_MODULE, 2U, 0U);
                break;
        case 10U:
                mm_extent_capacity = 0U;
                break;
        case 11U:
                mm_extents[0].meta |= (kword_t)1UL << MM_PIN_SHIFT;
                break;
        case 12U: /* Unsorted but otherwise disjoint table. */
                add_extent_v1609(030000UL, 0200UL, MM_TYPE_MODULE, 2U, 0U);
                break;
        case 13U: /* No matching owner is not evidence of committed free. */
                mm_extent_count = 0;
                break;
        case 14U: /* Normal FINALIZE+PREVM retry can release sole RAW. */
                u[PROC_FINALIZE_OFFSET] = PROC_FINALIZE_MARK |
                    PROC_FINALIZE_PREVM | PROC_FINISH_RETRY_ARMED_V1763 | 7UL;
                add_extent_v1609(060000UL, 0200UL, MM_TYPE_MODULE, V1609_SLOT, 0U);
                break;
        case 15U: /* Successful free, lost error reply. */
                terminal_fault_v1920 = 1U;
                break;
        case 16U: /* False successful free reply, source remains. */
                terminal_fault_v1920 = 2U;
                break;
        case 17U: /* Source retagged, not actually freed. */
                terminal_fault_v1920 = 3U;
                break;
        case 18U: /* Foreign interior claim after deleting original. */
                terminal_fault_v1920 = 4U;
                break;
        case 19U: /* Corrupt count after deletion. */
                terminal_fault_v1920 = 5U;
                break;
        case 20U: /* Ordinary native refusal; exact retry must work. */
                refuse_free_v1609 = 1;
                break;
        case 21U: /* Nonterminal timer marker without a source field. */
                u[PROC_FINALIZE_OFFSET] = PROC_SWAP_RETRY_TAG_V1507 | 01234UL;
                break;
        case 22U: /* Malformed FINALIZE must not erase restore kind. */
                u[PROC_FINALIZE_OFFSET] = PROC_FINALIZE_MARK | PROC_FINALIZE_PREVM |
                    PROC_PURE_INPLACE_ESCROW_V1919(V1609_BASE, PROC_PURE_DROP_TAG_V1919);
                break;
        case 23U: /* Terminal identity tag without a physical source. */
                u[PROC_FINALIZE_OFFSET] = PROC_PURE_TERM_TAG_V1920;
                break;
        }
        marker = u[PROC_FINALIZE_OFFSET];
        span = mm_extents[0].span;
        meta = mm_extents[0].meta;
        count = mm_extent_count;
        if (kind == 14U || kind == 15U) {
                if (vm_space_destroy(p, V1609_SLOT) || free_count_v1609 != 1 ||
                    mm_extent_count != (kind == 14U ? 1 : 0) ||
                    p->vm_state != ~(kword_t)0 || records_v1609[V1609_SLOT].state ||
                    u[PROC_SWAP_BACKING_OFFSET] || u[PROC_FINALIZE_OFFSET] != marker ||
                    proc_storage_expect_v30(V1609_SLOT, PROC_STORAGE_RESIDENT))
                        return 1;
                if (vm_space_destroy(p, V1609_SLOT) || free_count_v1609 != 1)
                        return 2;
                return 0;
        }
        expected_marker = marker;
        if (kind == 11U || (kind >= 16U && kind <= 20U))
                expected_marker |= PROC_PURE_TERM_ESCROW_V1920(V1609_BASE);
        if (vm_space_destroy(p, V1609_SLOT) == 0 ||
            p->vm_state != (V1609_WORDS << PROC_HALF_SHIFT) ||
            records_v1609[V1609_SLOT].state != V1609_BACKING ||
            u[PROC_SWAP_BACKING_OFFSET] != V1609_BACKING ||
            u[PROC_FINALIZE_OFFSET] != expected_marker || !PROC_TRANSITION(p) ||
            proc_storage_expect_v30(V1609_SLOT, PROC_STORAGE_PACKED))
                return 3;
        if (kind <= 13U || kind >= 21U) {
                if (free_count_v1609 || mm_extent_count != count ||
                    mm_extents[0].span != span || mm_extents[0].meta != meta)
                        return 4;
        } else if (free_count_v1609 != 1)
                return 5;
        if (kind == 11U) {
                /* Refusing a pin must retain the original identity too. */
                mm_extents[0].span = (V1609_RAW << 18U) | 060400UL;
                mm_extents[0].meta &= ~MM_PIN_FIELD_MASK;
                if (vm_space_destroy(p, V1609_SLOT) == 0 || free_count_v1609 ||
                    u[PROC_FINALIZE_OFFSET] != PROC_PURE_TERM_ESCROW_V1920(V1609_BASE))
                        return 9;
                mm_extents[0].span = span;
                if (vm_space_destroy(p, V1609_SLOT) || free_count_v1609 != 1 ||
                    mm_extent_count || u[PROC_FINALIZE_OFFSET])
                        return 10;
        }
        if (kind == 17U || kind == 18U || kind == 19U) {
                /* A later exact-shaped replacement cannot become the
                 * original RAW owner just because its slot matches. */
                terminal_fault_v1920 = 0U;
                mm_extent_count = 0;
                add_extent_v1609(060400UL, V1609_RAW, MM_TYPE_PACKED_PROCESS,
                    V1609_SLOT, 0U);
                if (vm_space_destroy(p, V1609_SLOT) == 0 ||
                    free_count_v1609 != 1 || mm_extent_count != 1 ||
                    u[PROC_FINALIZE_OFFSET] != PROC_PURE_TERM_ESCROW_V1920(V1609_BASE))
                        return 7;
                mm_extent_count = 0; /* lawful removal of injected replacement */
                if (vm_space_destroy(p, V1609_SLOT) || free_count_v1609 != 1 ||
                    records_v1609[V1609_SLOT].state || u[PROC_FINALIZE_OFFSET])
                        return 8;
        }
        if (kind == 16U || kind == 20U) {
                terminal_fault_v1920 = 0U;
                refuse_free_v1609 = 0;
                if (vm_space_destroy(p, V1609_SLOT) || free_count_v1609 != 2 ||
                    mm_extent_count || records_v1609[V1609_SLOT].state)
                        return 6;
        }
        return 0;
}

int
main(void)
{
        unsigned int kind;
        int rc;
        for (kind = 1U; kind <= 23U; ++kind) {
                rc = terminal_case_v1920(kind);
                if (rc)
                        return (int)(kind * 0100U) + rc;
        }
        return 0;
}
