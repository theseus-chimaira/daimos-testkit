/* Native PDP-6 RUN service: prepend the entire real v1664 fixture. */
#include "proc_pure_restore_v1384.h"
#include "proc_pure_ram_restore_v1391.h"
#include "proc_pure_bitmap_restore_v1664.h"

unsigned int proc_high_slot = SLOTS_V1661;
kword_t proc_sched_cursor;
kword_t proc_swap_pressure_ticks;
static unsigned int prefix_calls_v1667;
static unsigned int full_calls_v1667;

extern int proc_pure_mres_service_v1612(void);

int
mm_compact(kword_t words, kword_t alignment)
{
        (void)words;
        (void)alignment;
        return MM_ERR_FRAGMENTED;
}

int
mm_is_pinned(kword_t base)
{
        (void)base;
        return 1;
}

int
proc_pure_ram_drop_v1381(unsigned int slot)
{
        (void)slot;
        return MM_ERR_BUSY;
}

int
proc_pure_restore_v1384(unsigned int slot,
    proc_pure_prefix_loader_v1384 loader)
{
        (void)slot;
        (void)loader;
        ++prefix_calls_v1667;
        return MM_ERR_BUSY;
}

int
proc_pure_ram_restore_v1391(unsigned int slot,
    proc_pure_ram_loader_v1391 loader)
{
        (void)slot;
        (void)loader;
        ++full_calls_v1667;
        return MM_ERR_BUSY;
}

int
exec_image_prefix_backing_v1386(kword_t backing, kword_t base,
    kword_t uarea, kword_t prefix)
{
        (void)backing;
        (void)base;
        (void)uarea;
        (void)prefix;
        return -1;
}

int
exec_image_full_bounded_v1391(kword_t backing, kword_t base,
    kword_t uarea, kword_t words)
{
        return load_full_v1664(backing, base, uarea, words);
}

static int
service_case_v1667(unsigned int kind)
{
        struct proc *p = &processes_v1661[SLOT_V1661];
        kword_t *u = (kword_t *)(unsigned long)UAREA_V1661;
        int rc, successful;

        if (setup_v1664(kind == 1U))
                return 1;
        prefix_calls_v1667 = 0U;
        full_calls_v1667 = 0U;
        proc_high_slot = SLOTS_V1661;
        proc_sched_cursor = (kword_t)PROC_SCHED_SWAP_REQUEST |
            SLOT_V1661;
        proc_swap_pressure_ticks = 0UL;
        proc_current_slot = 0UL;
        PROC_CLEAR_TRANSITION(p);
        PROC_SET_STATE(p, PROC_SRUN);
        switch (kind) {
        case 2U: fault_v1664 = 2U; break; /* actual NOMEM refusal */
        case 3U: fault_v1664 = 1U; break; /* loader partial write */
        case 4U: fault_v1664 = 21U; break; /* quarantined rollback */
        case 5U: fault_v1664 = 5U; break; /* false MM target pin */
        case 6U: fault_v1664 = 36U; break; /* mode changed in loader */
        case 7U: {
                kword_t *packed = (kword_t *)(unsigned long)
                    MM_EXTENT_BASE(&mm_extents[0]);
                packed[1] = 0UL;
                break;
        }
        case 8U: proc_current_slot = SLOT_V1661; break;
        case 9U: PROC_SET_STATE(p, PROC_SLEEP); break;
        case 10U: proc_sched_cursor = SLOT_V1661; break;
        case 11U: storage_v1661[0] =
                      (kword_t)PROC_STORAGE_DISK << 4U; break;
        case 12U: u[PROC_SWAP_BACKING_OFFSET] ^= 1UL; break;
        case 13U: vfs_mount_root_base = (vnode_t *)0; break;
        case 14U: mm_extent_count = 2;
                  mm_extents[1].span = (10UL << 18U) |
                      EXTRA_BASE_V1662;
                  mm_extents[1].meta =
                      ((kword_t)MM_TYPE_PACKED_PROCESS << 18U) |
                      SLOT_V1661;
                  break;
        case 15U: proc_sched_cursor |= 020000UL; break;
        default: break;
        }
        rc = proc_pure_mres_service_v1612();
        fault_v1664 = 0U;
        successful = kind <= 1U || kind == 15U;
        if (pi_depth_v1661 || prefix_calls_v1667 ||
            full_calls_v1667)
                return 2;
        if (successful) {
                const kword_t *dest = (const kword_t *)(unsigned long)
                    APR_BASE_V1664;
                kword_t i;
                if (rc != (int)(01000UL | SLOT_V1661) ||
                    proc_sched_cursor != (01000UL | SLOT_V1661) ||
                    proc_swap_pressure_ticks ||
                    PROC_TRANSITION(p) ||
                    VM_PDP6_BASE(p) != APR_BASE_V1664 ||
                    storage_v1661[0] || mm_extent_count != 1 ||
                    MM_EXTENT_TYPE(&mm_extents[0]) != MM_TYPE_PROCESS ||
                    MM_EXTENT_PINS(&mm_extents[0]) ||
                    loads_v1664 != 1U)
                        return 3;
                for (i = 0UL; i < FULL_V1661; ++i) {
                        kword_t want = i < SKIP_V1661 ?
                            0500000UL + i :
                            (kind == 1U ? 0UL :
                             raw_word_v1662(i - SKIP_V1661));
                        if (dest[i] != want)
                                return 4;
                }
        } else {
                if (rc || proc_sched_cursor ==
                    (01000UL | SLOT_V1661) ||
                    VM_PDP6_BASE(p) != 0UL)
                        return 5;
                if (kind == 2U || kind == 3U || kind == 7U) {
                        if (PROC_TRANSITION(p) || mm_extent_count != 1 ||
                            MM_EXTENT_PINS(&mm_extents[0]) ||
                            proc_swap_pressure_ticks != 0100UL)
                                return 6;
                }
                if (kind >= 4U && kind <= 6U &&
                    (!PROC_TRANSITION(p) ||
                     proc_swap_pressure_ticks != 0100UL))
                        return 7;
        }
        return 0;
}

int
main(void)
{
        unsigned int kind;
        int rc;

        for (kind = 0U; kind <= 15U; ++kind) {
                rc = service_case_v1667(kind);
                if (rc)
                        return (int)(010000U + kind * 16U +
                            (unsigned int)rc);
        }
        return 0;
}
