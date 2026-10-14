/* C99 native PDP-6 dispatch contract, isolated lifecycle callbacks. */
#include "proc_swap.h"
#include "proc_storage_map_v28.h"
#include "proc_packed_v1.h"
extern int proc_swap_restore_dispatch_v083(int slot);
static struct proc slots[PROC_MIN_SLOTS];
static struct proc_swap_record backing[PROC_MIN_SLOTS];
static kword_t modes[PROC_STORAGE_MAP_WORDS_V28(PROC_MIN_SLOTS)];
struct proc *proc_table=slots;
struct proc_swap_record *proc_swap_records=backing;
struct proc_storage_map_v28 proc_storage_runtime_v29;
static int disk_calls,packed_calls;
int proc_swap_in(int slot) { ++disk_calls;return slot == 1 ? 0 : -1; }
int proc_swap_reload_pure(kword_t b,kword_t base) {return b && base ? 0 : -1;}
int proc_packed_try_restore_v082(unsigned int slot,kword_t b,
    proc_packed_pure_reload_v31 fn)
{
    ++packed_calls;
    return slot == 1 && b == 012345UL && fn == proc_swap_reload_pure ? 0 : -1;
}
int main(void)
{
    proc_storage_runtime_v29.words=modes;
    proc_storage_runtime_v29.slots=PROC_MIN_SLOTS;
    if(proc_swap_restore_dispatch_v083(1)==0)return 1;
    if(disk_calls || packed_calls)return 2;
    modes[0]=(kword_t)PROC_STORAGE_DISK << 2U;
    if(proc_swap_restore_dispatch_v083(1)!=0 || disk_calls!=1 || packed_calls)return 3;
    modes[0]=(kword_t)PROC_STORAGE_PACKED << 2U;
    if(proc_swap_restore_dispatch_v083(1)==0)return 4;
    backing[1].state=012345UL;
    if(proc_swap_restore_dispatch_v083(1)!=0 || disk_calls!=1 || packed_calls!=1)return 5;
    if(proc_swap_restore_dispatch_v083(0)==0 ||
       proc_swap_restore_dispatch_v083(PROC_MIN_SLOTS)==0)return 6;
    return 0;
}
