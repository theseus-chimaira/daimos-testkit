/* C99 host fixture for assembly-owned two-bit process storage transitions.
 * Portable swap fallback now calls the same checked publication contract
 * after commit. Illegal publication is a hard invariant violation.
 */
#include <stdio.h>
#include <stdlib.h>
#include "proc_storage_map_v28.h"

void
proc_swap_storage_invariant_v30(void)
{
    fputs("mm-v1: storage-mode invariant violation\n", stderr);
    abort();
}

int
proc_storage_publish_v30(unsigned int slot, unsigned int old_state,
    unsigned int new_state)
{
    return proc_storage_change_v28(&proc_storage_runtime_v29, slot,
        old_state, new_state);
}
