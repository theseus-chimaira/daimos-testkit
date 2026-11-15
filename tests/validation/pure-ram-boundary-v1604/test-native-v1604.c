/*
 * P1-E v1604: source-linked generic lifecycle vs PDP-6 PURE geometry.
 * No production VM or scheduler is activated by this test.
 * Only the layout routine may interpret the PURE prefix as an APR suffix.
 */
#include "proc_pure_lifecycle_v1604.h"
#include "vm_pdp6_pure_range_v1604.h"

#define SLOTS 8U
#define SLOT 1U
#define UAREA 040000UL
#define WORDS 02000UL
#define TEXT 0500UL
#define BACKING ((TEXT << PROC_SWAP_TEXT_SHIFT) | 012345UL)

kword_t __test_exit;
static struct proc slots[SLOTS];
static struct proc_swap_record records[SLOTS];
static kword_t modes[PROC_STORAGE_MAP_WORDS_V28(SLOTS)];
struct proc *proc_table = slots;
struct proc_swap_record *proc_swap_records = records;
struct proc_storage_map_v28 proc_storage_runtime_v29 = { modes, SLOTS };

static void
setup(void)
{
        struct proc *p = &slots[SLOT];
        kword_t *u = (kword_t *)(unsigned long)UAREA;
        unsigned int i;

        for (i = 0; i < PROC_UAREA_WORDS; ++i)
                u[i] = 0UL;
        p->meta = (UAREA << PROC_HALF_SHIFT) |
            ((kword_t)(PROC_F_UAREA | PROC_F_TRANSITION) <<
                PROC_FLAGS_SHIFT);
        p->vm_state = (WORDS << PROC_HALF_SHIFT) | 050000UL;
        p->sched = (kword_t)PROC_SLEEP << PROC_STATE_SHIFT;
        records[SLOT].state = BACKING;
}

static int
check_life(void)
{
        struct proc *p;
        struct proc *out = (struct proc *)0;
        kword_t back = 0UL;
        kword_t words = 0UL;
        kword_t *u = (kword_t *)(unsigned long)UAREA;

        if (pure_life_prepare_v1604(SLOT, 0U, &out, &back,
            &words) != MM_OK || out != &slots[SLOT] ||
            back != BACKING || words != WORDS)
                return 1;
        out = (struct proc *)0;
        back = words = 0UL;
        if (pure_life_prepare_v1604(0U, 0U, &out, &back,
            &words) != MM_ERR_INVAL || out || back || words)
                return 2;
        p = &slots[SLOT];
        PROC_CLEAR_TRANSITION(p);
        if (pure_life_prepare_v1604(SLOT, 0U, &out, &back,
            &words) != MM_ERR_INVAL || out || back || words)
                return 3;
        PROC_SET_TRANSITION(p);
        PROC_SET_STATE(p, PROC_SRUN);
        if (pure_life_prepare_v1604(SLOT, 0U, &out, &back,
            &words) != MM_ERR_INVAL)
                return 4;
        PROC_SET_STATE(p, PROC_STOP);
        if (pure_life_prepare_v1604(SLOT, 0U, &out, &back,
            &words) != MM_OK)
                return 5;
        u[PROC_FDCTL_OFFSET] |= PROC_USER_MAP_BIT;
        if (pure_life_prepare_v1604(SLOT, 0U, &out, &back,
            &words) != MM_ERR_BUSY)
                return 6;
        u[PROC_FDCTL_OFFSET] &= ~PROC_USER_MAP_BIT;
        u[PROC_FDCTL_OFFSET] |= PROC_FATAL_CLOSE_BIT;
        if (pure_life_prepare_v1604(SLOT, 0U, &out, &back,
            &words) != MM_ERR_BUSY)
                return 7;
        u[PROC_FDCTL_OFFSET] = 0UL;
        PROC_SET_STATE(p, PROC_ZOMB);
        if (pure_life_prepare_v1604(SLOT, 0U, &out, &back,
            &words) != MM_ERR_INVAL ||
            pure_life_prepare_v1604(SLOT, 1U, &out, &back,
            &words) != MM_OK)
                return 8;
        PROC_SET_STATE(p, PROC_FREE);
        if (pure_life_prepare_v1604(SLOT, 1U, &out, &back,
            &words) != MM_ERR_INVAL)
                return 9;
        return 0;
}

static int
check_geometry(void)
{
        kword_t skip = 07777UL;

        if (pdp6_pure_skip_v1604(BACKING, WORDS, &skip) != MM_OK ||
            skip != 0400UL)
                return 1;
        skip = 07777UL;
        if (pdp6_pure_skip_v1604(0UL, WORDS, &skip) != MM_ERR_INVAL ||
            skip != 07777UL)
                return 2;
        if (pdp6_pure_skip_v1604(BACKING, 0400UL, &skip) !=
            MM_ERR_INVAL || skip != 07777UL)
                return 3;
        if (pdp6_pure_skip_v1604(BACKING, 0UL, &skip) !=
            MM_ERR_INVAL || skip != 07777UL)
                return 4;
        if (pdp6_pure_skip_v1604(
            (0177UL << PROC_SWAP_TEXT_SHIFT), WORDS, &skip) != MM_OK ||
            skip != 0200UL)
                return 5;
        return 0;
}

int
main(void)
{
        int rc;
        setup();
        rc = check_life();
        if (rc)
                return 010 + rc;
        rc = check_geometry();
        if (rc)
                return 020 + rc;
        return 0;
}
