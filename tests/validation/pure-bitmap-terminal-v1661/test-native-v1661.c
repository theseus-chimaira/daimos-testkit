/* Source-linked PDP-6 mode3 terminal path and real MM-free regression. */
#include "proc_pure_bitmap_terminal_v1661.h"
#include "proc.h"
#include "proc_swap.h"
#include "proc_storage_map_v28.h"
#include "vm_pdp6.h"
#include "mm.h"

#define SLOT_V1661 2U
#define SLOTS_V1661 6U
#define UAREA_V1661 030000UL
#define PACKED_BASE_V1661 040000UL
#define ALT_BASE_V1661 045000UL
#define FULL_V1661 010000UL
#define SKIP_V1661 01200UL
#define RAW_V1661 (FULL_V1661 - SKIP_V1661)
#define PACKED_V1661 0241UL
#define BACKING_V1661 (((kword_t)SKIP_V1661 << PROC_SWAP_TEXT_SHIFT) | \
    012345UL)

static struct proc processes_v1661[SLOTS_V1661];
static struct proc_swap_record swap_v1661[SLOTS_V1661];
static kword_t storage_v1661[1];
struct proc *proc_table = processes_v1661;
struct proc_swap_record *proc_swap_records = swap_v1661;
struct proc_storage_map_v28 proc_storage_runtime_v29 = {
        storage_v1661, SLOTS_V1661
};
kword_t proc_current_slot;

/* ACTUAL MM assembly leaf below, not a mocked release algorithm. */
struct mm_extent mm_extents[MM_MAX_EXTENTS];
int mm_extent_count;
unsigned int mm_extent_capacity = MM_MAX_EXTENTS;
kword_t mm_arenas[MM_MAX_ARENAS];
kword_t mm_core_words;
int mm_arena_count;

static unsigned int pi_depth_v1661;
static unsigned int free_calls_v1661;
static int refuse_free_v1661;

extern int mm_free(kword_t, unsigned int, unsigned int);
kword_t __test_exit;

kword_t
mach_pi_disable(void)
{
        kword_t before = (kword_t)pi_depth_v1661;
        ++pi_depth_v1661;
        return before;
}

void
mach_pi_restore(kword_t saved)
{
        pi_depth_v1661 = (unsigned int)saved;
}

int
mm_terminal_free_v1661(kword_t base, unsigned int type,
    unsigned int owner)
{
        ++free_calls_v1661;
        if (pi_depth_v1661 != 1U)
                return MM_ERR_BUSY;
        if (refuse_free_v1661)
                return MM_ERR_BUSY;
        return mm_free(base, type, owner);
}

static void
reset_v1661(void)
{
        struct proc *p = &processes_v1661[SLOT_V1661];
        kword_t *u = (kword_t *)(unsigned long)UAREA_V1661;

        pi_depth_v1661 = 0U;
        free_calls_v1661 = 0U;
        refuse_free_v1661 = 0;
        proc_current_slot = 0UL;
        p->meta = (UAREA_V1661 << PROC_HALF_SHIFT) |
            ((kword_t)(PROC_F_UAREA | PROC_F_TRANSITION) <<
            PROC_FLAGS_SHIFT);
        p->sched = (kword_t)PROC_ZOMB << PROC_STATE_SHIFT;
        p->vm_state = FULL_V1661 << PROC_HALF_SHIFT;
        swap_v1661[SLOT_V1661].state = BACKING_V1661;
        u[PROC_SWAP_BACKING_OFFSET] = BACKING_V1661;
        storage_v1661[0] = (kword_t)PROC_STORAGE_BITMAP_V1661 <<
            (SLOT_V1661 * 2U);
        mm_extent_count = 1;
        mm_extent_capacity = MM_MAX_EXTENTS;
        mm_extents[0].span = (PACKED_V1661 << 18U) |
            PACKED_BASE_V1661;
        mm_extents[0].meta = ((kword_t)MM_TYPE_PACKED_PROCESS << 18U) |
            SLOT_V1661;
        mm_extents[1].span = 0UL;
        mm_extents[1].meta = 0UL;
}

static int
run_case_v1661(unsigned int kind)
{
        struct proc *p = &processes_v1661[SLOT_V1661];
        kword_t *u = (kword_t *)(unsigned long)UAREA_V1661;
        kword_t prior_mode, prior_span, prior_meta, second_span, second_meta;
        int count, rc;

        reset_v1661();
        switch (kind) {
        case 1U: /* RAW mode must never be discarded via BITMAP */
                storage_v1661[0] = (kword_t)PROC_STORAGE_PACKED << 4U;
                break;
        case 2U:
                mm_extents[0].meta = ((kword_t)MM_TYPE_PACKED_PROCESS <<
                    18U) | (SLOT_V1661 + 1U);
                break;
        case 3U: /* duplicate PROCESS/PACKED owner, no arbitrary choice */
                mm_extent_count = 2;
                mm_extents[1].span = (PACKED_V1661 << 18U) |
                    ALT_BASE_V1661;
                mm_extents[1].meta = ((kword_t)MM_TYPE_PACKED_PROCESS <<
                    18U) | SLOT_V1661;
                break;
        case 4U:
                mm_extents[0].meta |= (kword_t)1UL << MM_PIN_SHIFT;
                break;
        case 5U: /* RAW-sized span is not compressed */
                mm_extents[0].span = (RAW_V1661 << 18U) |
                    PACKED_BASE_V1661;
                break;
        case 6U: /* fewer words than required mask groups */
                mm_extents[0].span = ((RAW_V1661 / 36UL - 1UL) << 18U) |
                    PACKED_BASE_V1661;
                break;
        case 7U:
                u[PROC_SWAP_BACKING_OFFSET] ^= 1UL;
                break;
        case 8U:
                p->vm_state |= 02000UL;
                break;
        case 9U:
                PROC_CLEAR_TRANSITION(p);
                break;
        case 10U: /* even a late MM refusal keeps mode3 authoritative */
                refuse_free_v1661 = 1;
                break;
        case 11U:
                mm_extents[0].meta = ((kword_t)MM_TYPE_PROCESS << 18U) |
                    SLOT_V1661;
                break;
        case 12U:
                p->sched = (kword_t)PROC_FREE << PROC_STATE_SHIFT;
                break;
        case 13U:
                mm_extent_count = 0;
                break;
        case 14U: /* physical halfword overflow */
                mm_extents[0].span = (PACKED_V1661 << 18U) | 0777700UL;
                break;
        case 15U:
                mm_extent_capacity = 0U;
                break;
        case 16U:
                mm_extent_count = -1;
                break;
        case 17U: /* physical end exactly 01000000 is legal */
                mm_extents[0].span = (PACKED_V1661 << 18U) |
                    (01000000UL - PACKED_V1661);
                break;
        case 18U: /* invalid type carrying this process slot */
                mm_extents[0].meta = ((kword_t)5UL << 18U) |
                    SLOT_V1661;
                break;
        case 19U: /* unknown secondary process-slot owner */
                mm_extent_count = 2;
                mm_extents[1].span = (PACKED_V1661 << 18U) |
                    ALT_BASE_V1661;
                mm_extents[1].meta = ((kword_t)5UL << 18U) |
                    SLOT_V1661;
                break;
        case 20U: /* a MODULE owner uses a separate ID namespace */
                mm_extent_count = 2;
                mm_extents[1].span = (PACKED_V1661 << 18U) |
                    ALT_BASE_V1661;
                mm_extents[1].meta = ((kword_t)MM_TYPE_MODULE << 18U) |
                    SLOT_V1661;
                break;
        default:
                break;
        }

        prior_mode = storage_v1661[0];
        prior_span = mm_extents[0].span;
        prior_meta = mm_extents[0].meta;
        second_span = mm_extents[1].span;
        second_meta = mm_extents[1].meta;
        count = mm_extent_count;
        rc = proc_pure_bitmap_terminal_v1661(SLOT_V1661);
        if (pi_depth_v1661)
                return 1;
        if (kind == 0U || kind == 17U || kind == 20U) {
                if (rc != MM_OK || free_calls_v1661 != 1U ||
                    mm_extent_count != (kind == 20U ? 1 : 0) ||
                    (kind == 20U &&
                     (mm_extents[0].span != second_span ||
                      mm_extents[0].meta != second_meta)) ||
                    storage_v1661[0] != 0UL ||
                    u[PROC_SWAP_BACKING_OFFSET] != BACKING_V1661 ||
                    swap_v1661[SLOT_V1661].state != BACKING_V1661 ||
                    !PROC_TRANSITION(p))
                        return 2;
        } else {
                if (rc != (kind == 10U ? MM_ERR_BUSY : MM_ERR_INVAL) ||
                    free_calls_v1661 != (kind == 10U ? 1U : 0U) ||
                    mm_extent_count != count ||
                    mm_extents[0].span != prior_span ||
                    mm_extents[0].meta != prior_meta ||
                    mm_extents[1].span != second_span ||
                    mm_extents[1].meta != second_meta ||
                    storage_v1661[0] != prior_mode)
                        return 3;
        }
        return 0;
}

int
main(void)
{
        unsigned int kind;
        int rc;

        for (kind = 0U; kind <= 20U; ++kind) {
                rc = run_case_v1661(kind);
                if (rc != 0)
                        return (int)(kind * 8U + (unsigned int)rc);
        }
        return 0;
}
