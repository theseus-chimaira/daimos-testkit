/* v1680: source-linked PDP-6 terminal PACKED owner fail-closed test.
 * Production VM-destroy C and PDP-6 packed-detach ASM are not copied
 * or reimplemented. Existing v1609 MM fixture supplies exact owners.
 */
#define V1680_PEER_BASE (V1609_BASE + 02000UL)
#define V1680_PEER_SLOT (V1609_SLOT + 1U)

static int
peer_intact_v1680(void)
{
        int i;
        unsigned int seen = 0U;
        for (i = 0; i < mm_extent_count; ++i) {
                const struct mm_extent *e = &mm_extents[i];
                if (MM_EXTENT_OWNER(e) != V1680_PEER_SLOT)
                        continue;
                if (++seen != 1U ||
                    MM_EXTENT_BASE(e) != V1680_PEER_BASE ||
                    MM_EXTENT_WORDS(e) != V1609_RAW ||
                    MM_EXTENT_TYPE(e) != MM_TYPE_PACKED_PROCESS ||
                    MM_EXTENT_PINNED(e))
                        return 0;
        }
        return seen == 1U;
}

static int
case_terminal_pin_v1680(unsigned int pins)
{
        struct proc *p = &process_v1609[V1609_SLOT];
        kword_t *u = (kword_t *)(unsigned long)V1609_UAREA;
        unsigned int attempt;
        int result;

        prepare_v1609();
        add_extent_v1609(V1680_PEER_BASE, V1609_RAW,
            MM_TYPE_PACKED_PROCESS, V1680_PEER_SLOT, 0U);
        mm_extents[0].meta |= (kword_t)pins << MM_PIN_SHIFT;
        for (attempt = 0U; attempt != 4U; ++attempt) {
                result = vm_space_destroy(p, (int)V1609_SLOT);
                /* Original RAW terminal ASM must reject a pinned owner
                 * BEFORE calling mm_free, not trust MM to reject later.
                 * The adjacent independent owner must be untouched. */
                if (result == 0)
                        return 1;
                if (free_count_v1609)
                        return 2;
                if (mm_extent_count != 2)
                        return 3;
                if (((mm_extents[0].meta >> MM_PIN_SHIFT) & MM_PIN_MASK) != pins)
                        return 4;
                if (!peer_intact_v1680())
                        return 5;
                if (!unchanged_v1609())
                        return 6;
                if (p->vm_state != (V1609_WORDS << PROC_HALF_SHIFT))
                        return 7;
                if (records_v1609[V1609_SLOT].state != V1609_BACKING ||
                    u[PROC_SWAP_BACKING_OFFSET] != V1609_BACKING)
                        return 8;
                if (proc_storage_expect_v30(V1609_SLOT,
                        PROC_STORAGE_PACKED))
                        return 9;
        }
        /* The owner of the real MM pin eventually releases it; the
         * original terminal leaf must then retire only this process.
         * This fixture models that release with a descriptor update;
         * it does not claim actual PI6 or MM-unpin execution. */
        mm_extents[0].meta &= ~((kword_t)MM_PIN_MASK << MM_PIN_SHIFT);
        if (vm_space_destroy(p, (int)V1609_SLOT) != 0 ||
            mm_extent_count != 1 || free_count_v1609 != 1 ||
            !peer_intact_v1680() ||
            p->vm_state != ~(kword_t)0 ||
            proc_storage_expect_v30(V1609_SLOT,
                PROC_STORAGE_RESIDENT) ||
            records_v1609[V1609_SLOT].state ||
            u[PROC_SWAP_BACKING_OFFSET] ||
            failed_invariant_v1609)
                return 2;
        if (vm_space_destroy(p, (int)V1609_SLOT) != 0 ||
            mm_extent_count != 1 || !peer_intact_v1680() ||
            free_count_v1609 != 1)
                return 3;
        return 0;
}

static int
case_terminal_busy_v1680(void)
{
        struct proc *p = &process_v1609[V1609_SLOT];
        unsigned int attempt;
        int rc;

        prepare_v1609();
        add_extent_v1609(V1680_PEER_BASE, V1609_RAW,
            MM_TYPE_PACKED_PROCESS, V1680_PEER_SLOT, 0U);
        refuse_free_v1609 = 1;
        for (attempt = 0U; attempt != 4U; ++attempt) {
                rc = vm_space_destroy(p, (int)V1609_SLOT);
                if (rc == 0 || free_count_v1609 != (int)(attempt + 1U) ||
                    mm_extent_count != 2 || !peer_intact_v1680() ||
                    !unchanged_v1609() || failed_invariant_v1609)
                        return 1;
        }
        refuse_free_v1609 = 0;
        if (vm_space_destroy(p, (int)V1609_SLOT) != 0 ||
            free_count_v1609 != 5 || mm_extent_count != 1 ||
            !peer_intact_v1680() || failed_invariant_v1609)
                return 2;
        return 0;
}

int
main(void)
{
        int rc;
        unsigned int pins;
        for (pins = 1U; pins <= 2U; ++pins) {
                rc = case_terminal_pin_v1680(pins);
                if (rc)
                        return (int)(01000U + 0100U * pins +
                            (unsigned int)rc);
        }
        rc = case_terminal_busy_v1680();
        if (rc)
                return 02000 + rc;
        return 0;
}
