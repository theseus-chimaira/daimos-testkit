/* Native PDP-6 transaction integration, C99 deterministic MM mock.
 * Physical pointers are PDP-6 word addresses, never host byte addresses.
 */
#include "proc.h"
#include "proc_swap.h"
#include "proc_packed_inline_v079.h"
#include "proc_packed_boot_v38.h"
#include "proc_storage_map_v28.h"
#include "vm_pdp6.h"
#include "mm_internal.h"

#define SLOT 1U
#define WORDS 256U
#define OFFSET 128U
#define BACKING 012345UL
static kword_t source_data[WORDS];
static kword_t packed_data[WORDS];
static kword_t dest_raw[WORDS+02000];
static kword_t *dest_data;
static kword_t registry[PROC_MIN_SLOTS];
static kword_t modes[PROC_STORAGE_MAP_WORDS_V28(PROC_MIN_SLOTS)];
static struct proc procs[PROC_MIN_SLOTS];
static struct proc_swap_record swap_data[PROC_MIN_SLOTS];
struct mm_extent mm_extents[MM_MAX_EXTENTS];
kword_t mm_arenas[MM_MAX_ARENAS];
kword_t mm_core_words;
int mm_extent_count, mm_arena_count;
struct proc *proc_table = procs;
struct proc_swap_record *proc_swap_records = swap_data;
struct proc_storage_map_v28 proc_storage_runtime_v29;
struct proc_packed_layout_v36 proc_packed_runtime_v38;

static kword_t base_of(const kword_t *p) {return (kword_t)(unsigned long)p;}
static void add_extent(kword_t base, kword_t count, unsigned int type)
{
    struct mm_extent *e = &mm_extents[mm_extent_count++];
    e->span = (count << 18U) | base;
    e->meta = SLOT | ((kword_t)type << MM_TYPE_SHIFT);
}
static int index_of(kword_t base)
{
    int i;
    for (i=0;i<mm_extent_count;++i)
        if (MM_EXTENT_BASE(&mm_extents[i])==base) return i;
    return -1;
}
int mm_alloc_aligned_noreclaim(kword_t words, kword_t align,
    unsigned int type, unsigned int owner, unsigned int pref,kword_t *out)
{
    kword_t addr;
    (void)pref;
    if (owner!=SLOT) return MM_ERR_INVAL;
    if (type==MM_TYPE_PACKED_PROCESS && words<WORDS)
        addr=base_of(packed_data);
    else if (type==MM_TYPE_PROCESS && words==WORDS)
        addr=base_of(dest_data);
    else return MM_ERR_NOMEM;
    if (addr%align || index_of(addr)>=0) return MM_ERR_NOMEM;
    add_extent(addr,words,type); *out=addr; return MM_OK;
}
int mm_pin(kword_t base)
{
    int i=index_of(base);
    if(i<0) return MM_ERR_INVAL;
    mm_extents[i].meta+=(kword_t)1<<MM_PIN_SHIFT;return MM_OK;
}
int mm_unpin(kword_t base)
{
    int i=index_of(base);
    if(i<0 || !MM_EXTENT_PINNED(&mm_extents[i])) return MM_ERR_INVAL;
    mm_extents[i].meta-=(kword_t)1<<MM_PIN_SHIFT;return MM_OK;
}
int mm_free(kword_t base,unsigned int type,unsigned int owner)
{
    int i=index_of(base),j;
    if(i<0 || MM_EXTENT_PINNED(&mm_extents[i]) ||
       MM_EXTENT_TYPE(&mm_extents[i])!=type ||
       MM_EXTENT_OWNER(&mm_extents[i])!=owner) return MM_ERR_INVAL;
    for(j=i;j<mm_extent_count-1;++j) mm_extents[j]=mm_extents[j+1];
    --mm_extent_count;return MM_OK;
}
int proc_storage_get_v28(const struct proc_storage_map_v28 *m,unsigned int slot)
{
    if(!m || !m->words || slot>=m->slots)return -1;
    return (int)((m->words[slot/18U] >> ((slot%18U)*2U)) & 3UL);
}
static int reload(kword_t backing,kword_t base)
{
    unsigned int i; kword_t *p=(kword_t *)(unsigned long)base;
    if(backing!=BACKING)return -1;
    for(i=0;i<OFFSET;++i)p[i]=0777UL;
    return 0;
}
static int run_case(unsigned int sparse, unsigned int mixed)
{
    unsigned int i;
    kword_t base=base_of(source_data);
    dest_data=(kword_t *)(unsigned long)((base_of(dest_raw)+01777UL)&~01777UL);
    for (i=0;i<PROC_MIN_SLOTS;++i) { registry[i]=0; procs[i].meta=0;
        procs[i].vm_state=0; swap_data[i].state=0; }
    for (i=0;i<PROC_STORAGE_MAP_WORDS_V28(PROC_MIN_SLOTS);++i)modes[i]=0;
    mm_extent_count=0;
    proc_packed_runtime_v38.words=0; proc_packed_runtime_v38.slots=0;
    proc_packed_runtime_v38.capacity=0; proc_packed_runtime_v38.format=0;
    if (proc_packed_layout_init_v36(&proc_packed_runtime_v38,registry,
         PROC_MIN_SLOTS,2,sparse?PROC_PACKED_LAYOUT_SPARSE_V36:
         PROC_PACKED_LAYOUT_DENSE_V36)!=MM_OK)return 1;
    proc_storage_runtime_v29.words=modes;
    proc_storage_runtime_v29.slots=PROC_MIN_SLOTS;
    procs[SLOT].vm_state=((kword_t)WORDS<<18U)|base;
    procs[SLOT].meta=((kword_t)(PROC_F_TRANSITION|PROC_F_UAREA)<<PROC_FLAGS_SHIFT);
    swap_data[SLOT].state=BACKING;
    for(i=0;i<WORDS;++i)source_data[i]=i<OFFSET?0777UL:
        (mixed && i<OFFSET+8U ? 02000UL+i-OFFSET : 0UL);
    add_extent(base,WORDS,MM_TYPE_PROCESS);
    if(proc_packed_inline_evict_v079(SLOT,OFFSET)!=MM_OK)return 2;
    if(mm_extent_count!=1 || MM_EXTENT_TYPE(&mm_extents[0])!=MM_TYPE_PACKED_PROCESS ||
       MM_EXTENT_PINS(&mm_extents[0])!=0U)return 3;
    PROC_SET_TRANSITION(&procs[SLOT]);
    if(proc_packed_inline_restore_v079(SLOT,BACKING,reload)!=MM_OK)return 4;
    if(mm_extent_count!=1 || MM_EXTENT_TYPE(&mm_extents[0])!=MM_TYPE_PROCESS)return 5;
    for(i=0;i<WORDS;++i)if(dest_data[i]!=(i<OFFSET?0777UL:
        (mixed && i<OFFSET+8U ? 02000UL+i-OFFSET : 0UL)))return 6;
    if(proc_packed_layout_find_v36(&proc_packed_runtime_v38,SLOT))return 7;
    if(MM_EXTENT_PINS(&mm_extents[0]) ||
       proc_storage_get_v28(&proc_storage_runtime_v29,SLOT)!=PROC_STORAGE_RESIDENT ||
       PROC_TRANSITION(&procs[SLOT]))return 8;
    return 0;
}
int main(void)
{
    unsigned int sparse,mixed;
    int rc;
    for(sparse=0;sparse<2U;++sparse)
        for(mixed=0;mixed<2U;++mixed) {
            rc=run_case(sparse,mixed);
            if(rc)return rc+10*(int)sparse+20*(int)mixed;
        }
    return 0;
}
