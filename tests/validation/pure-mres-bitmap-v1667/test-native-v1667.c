/*
 * v1667 source-linked terminal mode2/mode3 dispatch on native PDP-6.
 * The runner prefixes the original v1609 KCORE/VM fixture (renaming
 * its main) and links actual v1609 RAW ASM, v1661 bitmap C and
 * the new opt-in PURE MRES dispatcher. This is not a mock terminal.
 */

#include "proc_pure_bitmap_terminal_v1661.h"

extern int proc_pure_term_v1667(int, struct proc *, kword_t);

#define ENCODED_V1667 045UL

unsigned int mm_extent_capacity = MM_MAX_EXTENTS;
kword_t proc_current_slot;
static unsigned int pi_depth_v1667;

kword_t
mach_pi_disable(void)
{
        kword_t previous = (kword_t)pi_depth_v1667;
        ++pi_depth_v1667;
        return previous;
}

void
mach_pi_restore(kword_t previous)
{
        pi_depth_v1667 = (unsigned int)previous;
}

static void
prepare_bitmap_v1667(void)
{
        prepare_v1609();
        modes_v1609[0] =
            (kword_t)PROC_STORAGE_BITMAP_V1661 << (2U * V1609_SLOT);
        mm_extents[0].span = (ENCODED_V1667 << 18U) | V1609_BASE;
        pi_depth_v1667 = 0U;
        mm_extent_capacity = MM_MAX_EXTENTS;
}

static int
case_v1667(unsigned int kind)
{
        struct proc *p = &process_v1609[V1609_SLOT];
        kword_t *u = (kword_t *)(unsigned long)V1609_UAREA;
        kword_t old_record, old_mode, old_u, old_span, old_meta;
        int old_count, rc, good;

        prepare_bitmap_v1667();
        switch (kind) {
        case 1U: modes_v1609[0] =
                     (kword_t)PROC_STORAGE_PACKED << (2U * V1609_SLOT);
                 mm_extents[0].span = (V1609_RAW << 18U) | V1609_BASE;
                 break;
        case 2U: modes_v1609[0] =
                     (kword_t)PROC_STORAGE_DISK << (2U * V1609_SLOT);
                 break;
        case 3U: modes_v1609[0] = 0UL; break;
        case 4U: u[PROC_SWAP_BACKING_OFFSET] ^= 1UL; break;
        case 5U: PROC_CLEAR_TRANSITION(p); break;
        case 6U: mm_extents[0].meta |=
                     (kword_t)1UL << MM_PIN_SHIFT; break;
        case 7U: mm_extents[0].span =
                     (V1609_RAW << 18U) | V1609_BASE; break;
        case 8U: mm_extents[0].span =
                     (10UL << 18U) | V1609_BASE; break;
        case 9U: add_extent_v1609(V1609_BASE + 02000UL,
                     ENCODED_V1667, MM_TYPE_PACKED_PROCESS,
                     V1609_SLOT, 0U); break;
        case 10U: mm_extents[0].meta =
                      ((kword_t)MM_TYPE_PROCESS << MM_TYPE_SHIFT) |
                      V1609_SLOT; break;
        case 11U: p->vm_state |= V1609_BASE; break;
        case 12U: refuse_free_v1609 = 1; break;
        case 13U: mm_extent_count = 0; break;
        case 14U: mm_extent_capacity = 0U; break;
        case 15U: records_v1609[V1609_SLOT].state = 0UL; break;
        case 16U: p->sched = (kword_t)PROC_FREE << PROC_STATE_SHIFT;
                  break;
        case 17U: mm_extents[0].meta =
                      ((kword_t)5UL << MM_TYPE_SHIFT) | V1609_SLOT;
                  break;
        case 18U: add_extent_v1609(V1609_BASE + 02000UL,
                      ENCODED_V1667, MM_TYPE_MODULE, V1609_SLOT, 0U);
                  break;
        case 19U: mm_extents[0].span =
                      (ENCODED_V1667 << 18U) | 0777777UL; break;
        case 20U: p->meta = 0UL; break;
        default: break;
        }

        old_record = records_v1609[V1609_SLOT].state;
        old_mode = modes_v1609[0];
        old_u = u[PROC_SWAP_BACKING_OFFSET];
        old_span = mm_extents[0].span;
        old_meta = mm_extents[0].meta;
        old_count = mm_extent_count;
        /* Common KCORE deliberately skips a terminal MRES call when
         * the map already says RESIDENT. Verify dispatcher refusal
         * directly for this inconsistent source owner instead.
         */
        if (kind == 3U)
                rc = proc_pure_term_v1667((int)V1609_SLOT, p,
                    old_record);
        else
                rc = proc_swap_detach((int)V1609_SLOT);
        good = kind == 0U || kind == 1U || kind == 18U;
        if (pi_depth_v1667 || (rc == 0) != good ||
            disk_free_count_v1609 || failed_invariant_v1609)
                return 1;
        if (good) {
                if (records_v1609[V1609_SLOT].state ||
                    u[PROC_SWAP_BACKING_OFFSET] ||
                    modes_v1609[0] != 0UL ||
                    (u[PROC_CRED_OFFSET] & PROC_SWAP_MOUNT_EXT_BIT) ||
                    mm_extent_count != (kind == 18U ? 1 : 0) ||
                    free_count_v1609 != 1)
                        return 2;
                if (kind == 18U &&
                    (MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_MODULE ||
                     MM_EXTENT_OWNER(&mm_extents[0]) != V1609_SLOT))
                        return 3;
                if (proc_swap_detach((int)V1609_SLOT) != 0 ||
                    free_count_v1609 != 1)
                        return 4;
        } else if (records_v1609[V1609_SLOT].state != old_record ||
            u[PROC_SWAP_BACKING_OFFSET] != old_u ||
            modes_v1609[0] != old_mode ||
            mm_extent_count != old_count ||
            mm_extents[0].span != old_span ||
            mm_extents[0].meta != old_meta ||
            free_count_v1609 != (kind == 12U ? 1 : 0))
                return 5;
        return 0;
}

int
main(void)
{
        unsigned int k;
        int rc;
        for (k = 0U; k <= 20U; ++k) {
                rc = case_v1667(k);
                if (rc)
                        return (int)(04000U + (k << 4U) +
                            (unsigned int)rc);
        }
        return 0;
}
