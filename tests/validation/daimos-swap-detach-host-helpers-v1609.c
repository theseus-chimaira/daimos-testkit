/*
 * Host-only disk detach fixtures cannot execute PDP-6 machine code.
 * The real packed-owner release is separately tested by v1609 on
 * native PDP-6 with the actual MM owner scan and VM destroy leaf.
 * These tests contain only DISK/RESIDENT process records and test
 * the real common C detach body. The selected disk MRES is modeled
 * here; its actual PDP-6 assembler is tested by v1666 native guest.
 */
#include "proc.h"
#include "proc_packed_v1.h"
#include "proc_swap.h"
#include "proc_storage_map_v28.h"
#include "vm_pdp6.h"
#include "bstore.h"

extern int test_disk_mode_v1666;
extern int proc_storage_publish_v30(unsigned int, unsigned int,
    unsigned int);
extern void proc_swap_storage_invariant_v30(void);

int
proc_storage_expect_v30(unsigned int slot, unsigned int mode)
{
        return slot == 2U && mode == (unsigned int)test_disk_mode_v1666 ?
            0 : -1;
}

int
proc_swap_term_v1666(int slot, struct proc *p, kword_t state)
{
        kword_t first, blocks;

        if (proc_storage_expect_v30((unsigned int)slot,
            PROC_STORAGE_DISK) != 0 || VM_PDP6_BASE(p) || !state)
                return -1;
        first = (state >> 18U) & MM_HALF_MASK;
        blocks = state & MM_HALF_MASK;
        if (!blocks || proc_swap_blocks_used < blocks ||
            backstore_free(first, blocks) != 0)
                return -1;
        proc_swap_blocks_used -= blocks;
        if (proc_storage_publish_v30((unsigned int)slot,
            PROC_STORAGE_DISK, PROC_STORAGE_RESIDENT) != 0)
                proc_swap_storage_invariant_v30();
        return 0;
}
