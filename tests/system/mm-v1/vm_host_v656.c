/* C99 host reference for the native PDP-6 VM assembly lifecycle.
 * This file belongs only to daimos-testkit. Keep its contracts aligned
 * with system/kernel/proc/vm_pdp6.s, not with deleted production C code.
 */
#include "vm_pdp6.h"
#include "mm.h"
#include "proc.h"
#include "proc_swap.h"
#include "proc_storage_map_v28.h"

extern void fs_move_words(const kword_t *, kword_t *, unsigned int);
extern void proc_runq_add(unsigned int);
extern void proc_runq_remove(unsigned int);
extern struct proc_storage_map_v28 proc_storage_runtime_v29;

int
vm_space_can_swap(const struct proc *p)
{
        kword_t base = VM_PDP6_BASE(p);

        return base != 0UL && !mm_is_pinned(base);
}

int
vm_extent_move(unsigned int owner, kword_t base, kword_t words,
    kword_t new_base)
{
        struct proc *p;
        unsigned int state;

        if (owner == (unsigned int)proc_current_slot ||
            owner >= proc_slots || new_base == base ||
            (new_base & (VM_EXTENT_ALIGN_WORDS - 1UL)) != 0UL)
                return MM_ERR_BUSY;
        p = &proc_table[owner];
        if (PROC_TRANSITION(p) ||
            (PROC_HAS_UAREA(p) && PROC_USER_MAPPING_HELD(p)))
                return MM_ERR_BUSY;
        state = PROC_STATE(p);
        if (!PROC_HAS_UAREA(p) && state == PROC_SRUN)
                return MM_ERR_BUSY;
        if (PROC_HAS_UAREA(p)) {
                PROC_CTL_WORD(p) |= (kword_t)PROC_STOP_MM << PROC_STOP_SHIFT;
                proc_runq_remove(owner);
                PROC_SET_STATE(p, PROC_STOP);
        }
        PROC_SET_TRANSITION(p);
        fs_move_words((const kword_t *)(unsigned long)base,
            (kword_t *)(unsigned long)new_base, (unsigned int)words);
        VM_PDP6_SET_BASE(p, new_base);
        PROC_CLEAR_TRANSITION(p);
        if (PROC_HAS_UAREA(p)) {
                PROC_CTL_WORD(p) &=
                    ~((kword_t)PROC_STOP_MM << PROC_STOP_SHIFT);
                if (PROC_STOP_REASONS(p) == 0U) {
                        PROC_SET_STATE(p, state);
                        if (state == PROC_SRUN)
                                proc_runq_add(owner);
                }
        }
        return MM_OK;
}

int
vm_space_destroy(struct proc *p, unsigned int owner)
{
        kword_t base;
        unsigned int mode;

        /* The fixture exercises raw MM-backed extents, not MEMFS XIP.
         * Reject packed/invalid modes rather than freeing foreign memory.
         */
        mode = proc_storage_get_v28(&proc_storage_runtime_v29, owner);
        if (mode != PROC_STORAGE_RESIDENT && mode != PROC_STORAGE_DISK)
                return -1;
        base = VM_PDP6_BASE(p);
        if (mode == PROC_STORAGE_DISK && base != 0UL)
                return -1;
        if (base != 0UL &&
            mm_free(base, MM_TYPE_PROCESS, owner) != MM_OK)
                return -1;
        proc_swap_detach((int)owner);
        VM_SPACE_RESET(p);
        return 0;
}
