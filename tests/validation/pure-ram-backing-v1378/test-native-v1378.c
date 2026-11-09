/*
 * PDP-6 v1378 PURE backing lifetime regression.
 *
 * Reuse the already accepted v1377 MM/loader fixture and link the actual
 * resident assembler vnode/mount guards. Test the slot/mount extension bit
 * and every source-MM release boundary without a second mocked VFS guard.
 */
#define mm_free mm_free_fixture_v1378
#define main previous_main_v1377
#include "test-native-v1377.c"
#undef main
#undef mm_free

#define HI_MOUNT_V1378 18U
#define HI_SLOT_V1378 (HI_MOUNT_V1378 - 1U)
#define HIGH_BACKING_V1378 +    ((TEXT << PROC_SWAP_TEXT_SHIFT) | +     (((kword_t)HI_SLOT_V1378 & PROC_SWAP_MOUNT_MASK) << +        PROC_SWAP_MOUNT_SHIFT) | 012345UL)
#define HI_NODE_V1378 +    VFS_NODE(6U, VFS_MOUNT_KIND(HI_MOUNT_V1378, 1U), 012345U)

unsigned int proc_high_slot = SLOTS;
extern int proc_swap_backing_busy(vnode_t node);
extern int proc_swap_mount_busy(unsigned int mount);

unsigned int guard_checks_v1378;
unsigned int free_checks_v1378;
static int inside_free_v1378;

static int
guard_active_v1378(void)
{
        ++guard_checks_v1378;
        if (proc_swap_backing_busy(HI_NODE_V1378) != 1 ||
            proc_swap_mount_busy(HI_MOUNT_V1378) != 1)
                return 0;
        if (proc_swap_backing_busy(HI_NODE_V1378 + 1UL) != 0 ||
            proc_swap_mount_busy(HI_MOUNT_V1378 + 1U) != 0 ||
            proc_swap_mount_busy(HI_MOUNT_V1378 - 1U) != 0)
                return 0;
        return 1;
}

static int
reload_high_v1378(kword_t backing, kword_t base, kword_t uarea)
{
        unsigned int i;
        kword_t *dest = (kword_t *)(unsigned long)base;
        if (backing != HIGH_BACKING_V1378 || uarea != UAREA ||
            base != RESTORE || !guard_active_v1378())
                return -1;
        for (i = 020U; i < WORDS; ++i)
                dest[i] = i < OMIT ? TEXT_PATTERN : 07777UL;
        return 0;
}

/*
 * Interpose on the v1377 fixture's MM free stub. This verifies that
 * executable guards stay published at the one fallible MM commit point:
 * old APR release, inactive suffix release and terminal inactive discard.
 */
int
mm_free(kword_t base, unsigned int type, unsigned int owner)
{
        if (!inside_free_v1378) {
                inside_free_v1378 = 1;
                ++free_checks_v1378;
                if (!guard_active_v1378()) {
                        inside_free_v1378 = 0;
                        return MM_ERR_INVAL;
                }
                inside_free_v1378 = 0;
        }
        return mm_free_fixture_v1378(base, type, owner);
}

static int
guard_absent_v1378(void)
{
        return proc_swap_backing_busy(HI_NODE_V1378) == 0 &&
            proc_swap_mount_busy(HI_MOUNT_V1378) == 0;
}

int
main(void)
{
        struct proc *p = &process_slots[SLOT];
        kword_t *uarea = (kword_t *)(unsigned long)UAREA;
        kword_t *source = (kword_t *)(unsigned long)SOURCE;
        kword_t *dest = (kword_t *)(unsigned long)RESTORE;
        unsigned int i;

        mm_extent_count = 0;
        add_extent(SOURCE, WORDS, MM_TYPE_PROCESS);
        for (i = 0U; i < PROC_UAREA_WORDS; ++i)
                uarea[i] = 0UL;
        for (i = 0U; i < WORDS; ++i)
                source[i] = i < OMIT ? TEXT_PATTERN : PATTERN + i;
        proc_storage_runtime_v29.words = mode_words;
        proc_storage_runtime_v29.slots = SLOTS;
#ifndef DAIMOS_TEST_NO_LAYOUT_V1380
        if (proc_packed_layout_init_v36(&proc_packed_runtime_v38,
            layout_words, SLOTS, 2U, PROC_PACKED_LAYOUT_DENSE_V36) !=
            MM_OK)
                return 1;
#endif
        p->meta = (UAREA << PROC_HALF_SHIFT) |
            ((kword_t)(PROC_F_UAREA | PROC_F_TRANSITION) <<
                PROC_FLAGS_SHIFT);
        p->vm_state = (WORDS << PROC_HALF_SHIFT) | SOURCE;
        p->sched = (kword_t)PROC_SLEEP << PROC_STATE_SHIFT;
        swap_slots[SLOT].state = HIGH_BACKING_V1378;
        uarea[PROC_CRED_OFFSET] |= PROC_SWAP_MOUNT_EXT_BIT;

        if (!guard_active_v1378())
                return 2;
        /* A public mount above 16 must not alias its low four-bit slot
         * with an unrelated earlier mount. The fifth bit is authoritative.
         */
        uarea[PROC_CRED_OFFSET] &= ~PROC_SWAP_MOUNT_EXT_BIT;
        if (!guard_absent_v1378())
                return 11;
        uarea[PROC_CRED_OFFSET] |= PROC_SWAP_MOUNT_EXT_BIT;
        if (!guard_active_v1378())
                return 12;
        if (proc_pure_ram_drop_v1377(SLOT) != MM_OK)
                return 3;
        if (!guard_active_v1378() ||
            uarea[PROC_SWAP_BACKING_OFFSET] != HIGH_BACKING_V1378)
                return 4;
        PROC_SET_TRANSITION(p);
        if (proc_pure_ram_restore_v1377(SLOT, reload_high_v1378) != MM_OK)
                return 5;
        if (!guard_active_v1378() || VM_PDP6_BASE(p) != RESTORE ||
            uarea[PROC_SWAP_BACKING_OFFSET] != 0UL)
                return 6;
        for (i = 020U; i < WORDS; ++i)
                if (dest[i] != (i < OMIT ? TEXT_PATTERN : PATTERN + i))
                        return 7;
        PROC_SET_TRANSITION(p);
        if (proc_pure_ram_drop_v1377(SLOT) != MM_OK)
                return 8;
        PROC_SET_STATE(p, PROC_ZOMB);
        PROC_SET_TRANSITION(p);
        if (proc_pure_ram_discard_v1377(SLOT) != MM_OK ||
            !guard_absent_v1378() ||
            (uarea[PROC_CRED_OFFSET] & PROC_SWAP_MOUNT_EXT_BIT))
                return 9;
        if (free_checks_v1378 != 4U || guard_checks_v1378 < 8U)
                return 10;
        return 0;
}
