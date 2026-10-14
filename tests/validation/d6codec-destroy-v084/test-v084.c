/* Native PDP-6 lifecycle teardown dispatch, mock registered owner. */
#include "proc_packed_boot_v38.h"
#include "proc_packed_teardown_v39.h"
#include "proc_swap.h"
#include "vm_pdp6.h"
extern int proc_packed_destroy_dispatch_v084(unsigned int slot);
static struct proc procs[PROC_MIN_SLOTS];
static struct proc_swap_record records[PROC_MIN_SLOTS];
static kword_t modes[PROC_STORAGE_MAP_WORDS_V28(PROC_MIN_SLOTS)];
struct proc *proc_table=procs;
struct proc_swap_record *proc_swap_records=records;
struct proc_storage_map_v28 proc_storage_runtime_v29;
struct proc_packed_layout_v36 proc_packed_runtime_v38;
static int discarded,fail_discard;
int proc_storage_get_v28(const struct proc_storage_map_v28 *m,unsigned int slot)
{
    if(!m || !m->words || slot>=m->slots)return -1;
    return (int)((m->words[slot/18U] >> ((slot%18U)*2U)) & 3UL);
}
int proc_packed_teardown_guard_v39(struct proc_packed_layout_v36 *layout,
    unsigned int slot)
{
    ++discarded;
    return layout==&proc_packed_runtime_v38 && slot==1 && !fail_discard ?
        MM_OK : MM_ERR_INVAL;
}
int main(void)
{
    proc_storage_runtime_v29.words=modes;
    proc_storage_runtime_v29.slots=PROC_MIN_SLOTS;
    if(proc_packed_destroy_dispatch_v084(1)!=-1)return 1;
    PROC_SET_TRANSITION(&procs[1]);
    if(proc_packed_destroy_dispatch_v084(1)!=0)return 2;
    modes[0]=(kword_t)PROC_STORAGE_DISK<<2U;
    if(proc_packed_destroy_dispatch_v084(1)!=0)return 3;
    modes[0]=(kword_t)PROC_STORAGE_PACKED<<2U;
    records[1].state=012345UL;
    fail_discard=1;
    if(proc_packed_destroy_dispatch_v084(1)!=-1 ||
       records[1].state!=012345UL || discarded!=1)return 4;
    fail_discard=0;
    if(proc_packed_destroy_dispatch_v084(1)!=1 ||
       records[1].state || discarded!=2)return 5;
    if(proc_packed_destroy_dispatch_v084(0)!=-1 ||
       proc_packed_destroy_dispatch_v084(PROC_MIN_SLOTS)!=-1)return 6;
    return 0;
}
