/* C99 host contract test for the PDP-6 two-bit process storage map. */
#include <stdio.h>
#include "proc_storage_map_v28.h"

int main(void)
{
    struct proc_storage_map_v28 map = { 0, 0 };
    kword_t words[PROC_STORAGE_MAP_WORDS_V28(40)] = { 0 };
    unsigned int slot;
    if (proc_storage_map_init_v28(&map, words, 40U) != 0)
        return 1;
    for (slot = 1U; slot < 40U; ++slot)
        if (proc_storage_get_v28(&map, slot) != PROC_STORAGE_RESIDENT)
            return 2;
    for (slot = 1U; slot < 40U; ++slot)
        if (proc_storage_change_v28(&map, slot, PROC_STORAGE_RESIDENT,
                PROC_STORAGE_DISK) != 0)
            return 3;
    for (slot = 1U; slot < 40U; ++slot)
        if (proc_storage_change_v28(&map, slot, PROC_STORAGE_RESIDENT,
                PROC_STORAGE_PACKED) == 0)
            return 4;
    for (slot = 1U; slot < 40U; ++slot)
        if (proc_storage_change_v28(&map, slot, PROC_STORAGE_DISK,
                PROC_STORAGE_RESIDENT) != 0)
            return 5;
    if (proc_storage_change_v28(&map, 0U, PROC_STORAGE_RESIDENT,
            PROC_STORAGE_DISK) == 0)
        return 6;
    if (proc_storage_change_v28(&map, 40U, PROC_STORAGE_RESIDENT,
            PROC_STORAGE_DISK) == 0)
        return 7;
    puts("mm-storage-v117: PASS");
    return 0;
}
