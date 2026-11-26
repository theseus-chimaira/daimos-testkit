/* Native K12: real MM table, pin, unpin, rebase, storage map and codec.
 * Fault wrappers affect only replies or explicitly named witness fields.
 * No physical backing I/O is used during preparation or cancellation. */
#include "proc_pure_bitmap_prefix_v1978.h"
#include "proc_pure_ram_v1381.h"
#include "proc_swap.h"
#include "proc_storage_map_v28.h"
#include "vm_pdp6.h"
#include "mm_pure_rebase_v1381.h"
#include "mm_internal.h"
#include "memfs.h"
#include "bstore.h"
#include "fs_mres.h"

#define SLOT 1U
#define SLOTS 4U
#define UAREA 040000UL
#define BASE 050000UL
#define WORDS 02000UL
#define TEXT 0500UL
#define PREFIX 0400UL
#define RAW (WORDS-PREFIX)
#define SUFFIX (BASE+PREFIX)
#define BACKING ((TEXT << PROC_SWAP_TEXT_SHIFT) | 012345UL)
#define GUARD 0123456701234UL
#define IDENTITY (((kword_t)MEMFS_PROVIDER << PROC_SWAP_PROVIDER_SHIFT_V1924) | PROC_SWAP_MUTABLE_V1976)
#define RAW_VALUE(i) ((i)%5UL ? 0UL : GUARD ^ ((i)+1UL))

kword_t __test_exit, diag_case_v1978, diag_rc_v1978, diag_cases_v1978;
static struct proc slots[SLOTS];
static struct proc_swap_record records[SLOTS];
static kword_t modes[PROC_STORAGE_MAP_WORDS_V28(SLOTS)];
struct proc *proc_table = slots;
struct proc_swap_record *proc_swap_records = records;
struct proc_storage_map_v28 proc_storage_runtime_v29;
unsigned int proc_slots = SLOTS, proc_high_slot = SLOTS;
kword_t proc_current_slot, proc_rt_owner;
struct mm_extent mm_extents[MM_MAX_EXTENTS];
kword_t backstore_blocks, backstore_blocks_used, proc_swap_blocks_used;
unsigned int backstore_enabled;
kword_t *backstore_bitmap;
static vnode_t roots[1];
vnode_t vfs_namespace_root;
vnode_t *vfs_mount_root_base = roots;
kword_t vfs_mount_limit = 1UL;
kword_t fs_memfs_service_jump, fs_dtfs_service_jump;
kword_t fs_d6fs_service_jump, fs_tsfs_service_jump;
kword_t *dtfs_media_base, *tsfs_file_shape_base;
kword_t *tsfs_extent_media_base, *d6fs_reader_slots_base;
static struct pure_bitmap_lease_v1978 lease;
static struct mm_extent before[4];
static kword_t u_before[PROC_UAREA_WORDS];
static kword_t *const u = (kword_t *)UAREA;
static kword_t *const image = (kword_t *)BASE;
static unsigned int pin_fault, unpin_fault, rebase_fault, encode_fault;
static unsigned int pin_calls, unpin_calls, rebase_calls, encode_calls, bad_call;
static unsigned int shape;

extern kword_t mach_pi_disable(void);
extern void mach_pi_restore(kword_t);
extern int proc_storage_expect_v30(unsigned int, unsigned int);
extern int legacy_gate_v1978(unsigned int, unsigned int);
extern kword_t pi_state_v1978(void);
int fs_mres_no_service(void) { return -1; }
int vfs_readonly(vnode_t node) { (void)node; return 0; }
/* Unrelated allocator services must never be reached. */
int vm_extent_move(unsigned int owner,kword_t base,kword_t words,kword_t target)
{ (void)owner; (void)base; (void)words; (void)target; bad_call=1U; return MM_ERR_BUSY; }
int proc_swap_reclaim(kword_t words,kword_t align,unsigned int excluded)
{ (void)words; (void)align; (void)excluded; bad_call=2U; return MM_ERR_BUSY; }
int fs_memory_reclaim(kword_t words,unsigned int level)
{ (void)words; (void)level; bad_call=3U; return MM_ERR_BUSY; }

/* The real MM operations execute unless an explicit pre-operation
 * refusal is selected. Lost replies occur AFTER the actual mutation. */
int pin_v1978(kword_t base)
{
        int rc;
        ++pin_calls;
        if (pi_state_v1978() & 0200UL) bad_call=6U;
        if (base!=BASE || u[PROC_FINALIZE_OFFSET]!=
            PROC_PURE_INPLACE_ESCROW_V1919(SUFFIX,PROC_PURE_DROP_TAG_V1919)) bad_call=4U;
        if (pin_fault==1U) return MM_ERR_BUSY;
        rc=mm_pin(base);
        if (pin_fault==2U) return MM_ERR_BUSY;
        if (pin_fault==3U) mm_extents[1].meta ^= 3UL; /* foreign owner */
        return rc;
}
int unpin_v1978(kword_t base)
{
        int rc;
        ++unpin_calls;
        if (pi_state_v1978() & 0200UL) bad_call=6U;
        if (unpin_fault==1U) return MM_ERR_BUSY;
        rc=mm_unpin(base);
        return unpin_fault==2U?MM_ERR_BUSY:rc;
}
int rebase_v1978(kword_t base,unsigned int slot,kword_t skip,kword_t words)
{
        int rc;
        ++rebase_calls;
        if (pi_state_v1978() & 0200UL) bad_call=6U;
        if (rebase_fault==1U) return MM_ERR_BUSY;
        rc=mm_pure_rebase_pinned_v1381(base,slot,skip,words);
        return rebase_fault==2U?MM_ERR_BUSY:rc;
}
int encode_v1978(kword_t source,kword_t raw,kword_t target,kword_t capacity,
    unsigned int direction,kword_t *count)
{
        int rc;
        ++encode_calls;
        if (pi_state_v1978() & 0200UL) bad_call=6U;
        if (source!=SUFFIX || raw!=RAW || target!=BASE || capacity!=PREFIX ||
            direction!=0U || MM_EXTENT_PINS(&mm_extents[1])!=1U ||
            u[PROC_FINALIZE_OFFSET]!=PROC_PURE_BITMAP_ESCROW_V1978(SUFFIX)) bad_call=5U;
        rc=pbmd_encode_v1977(source,raw,target,capacity,direction,count);
        if (encode_fault && rc==MM_OK) return PBMD_WRITE_FAULT_V1977;
        return rc;
}

static kword_t raw_value(kword_t i)
{
        if (shape==1U) return GUARD ^ (i+1UL);
        if (shape==2U) return i&1UL?0UL:GUARD ^ (i+1UL);
        return RAW_VALUE(i);
}
static void extent(unsigned int i,kword_t base,kword_t words,unsigned int kind,unsigned int owner)
{
        mm_extents[i].span=(words<<18U)|base;
        mm_extents[i].meta=((kword_t)kind<<MM_TYPE_SHIFT)|owner;
}
static void reset(unsigned int density)
{
        unsigned int i;
        shape=density;
        proc_table=slots; proc_swap_records=records;
        proc_slots=proc_high_slot=SLOTS; proc_current_slot=proc_rt_owner=0UL;
        proc_storage_runtime_v29.words=modes; proc_storage_runtime_v29.slots=SLOTS;
        modes[0]=0UL;
        slots[SLOT].meta=(UAREA<<18U)|((kword_t)(PROC_F_UAREA|PROC_F_TRANSITION)<<PROC_FLAGS_SHIFT);
        VM_PDP6_SET_SPACE(&slots[SLOT],WORDS,BASE);
        slots[SLOT].sched=(kword_t)PROC_SLEEP<<PROC_STATE_SHIFT;
        records[SLOT].state=BACKING;
        for (i=0U;i<PROC_UAREA_WORDS;++i) u[i]=0UL;
        u[PROC_CRED_OFFSET]=IDENTITY;
        for (i=0U;i<WORDS;++i) image[i]=i<PREFIX?GUARD:raw_value(i-PREFIX);
        image[-1]=GUARD;
        for (i=0U;i<0200U;++i) image[WORDS+i]=GUARD ^ i;
        mm_core_words=0100000UL; mm_arena_count=1;
        mm_arenas[0]=(040000UL<<18U)|040000UL;
        mm_extent_capacity=MM_MAX_EXTENTS; mm_extent_count=3;
        extent(0,UAREA,PROC_UAREA_WORDS,MM_TYPE_KERNEL_DYNAMIC,01000U+SLOT);
        extent(1,BASE,WORDS,MM_TYPE_PROCESS,SLOT);
        extent(2,BASE+WORDS,0200UL,MM_TYPE_PROCESS,2U);
        backstore_enabled=0U; backstore_blocks=backstore_blocks_used=proc_swap_blocks_used=0UL;
        backstore_bitmap=0;
        roots[0]=VFS_NODE(MEMFS_PROVIDER,VFS_MOUNT_KIND(1U,1U),1U);
        vfs_mount_root_base=roots; fs_memfs_service_jump=0254000001234UL;
        pin_fault=unpin_fault=rebase_fault=encode_fault=0U;
        pin_calls=unpin_calls=rebase_calls=encode_calls=bad_call=0U;
        lease.vm_state=lease.backing=lease.uarea=lease.identity=GUARD;
}
static int raw_ok(void)
{
        kword_t i;
        if (image[-1]!=GUARD) return 0;
        for(i=0UL;i<0200UL;++i) if(image[WORDS+i]!=(GUARD ^ i)) return 0;
        for(i=0UL;i<RAW;++i) if(image[PREFIX+i]!=raw_value(i)) return 0;
        return 1;
}
static int text_ok(void)
{
        kword_t i;
        for(i=0UL;i<PREFIX;++i) if(image[i]!=GUARD) return 0;
        return raw_ok();
}
static int candidate_ok(void)
{
        kword_t i,j,mask,bit,count=0UL,groups=(RAW+35UL)/36UL;
        kword_t lit=groups;
        for(i=0UL;i<groups;++i) {
                mask=0UL; bit=(kword_t)1UL<<35U;
                for(j=0UL;j<36UL && i*36UL+j<RAW;++j) {
                        if(raw_value(i*36UL+j)) {
                                mask|=bit;
                                if(image[lit++]!=raw_value(i*36UL+j)) return 0;
                                ++count;
                        }
                        bit>>=1U;
                }
                if(image[i]!=mask) return 0;
        }
        if(lit!=groups+count || lit>PREFIX ||
            u[PROC_FINALIZE_OFFSET]!=(PROC_PURE_BITMAP_ESCROW_V1978(SUFFIX)|lit)) return 0;
        for(i=lit;i<PREFIX;++i) if(image[i]!=GUARD) return 0;
        for(i=0UL;i<PROC_UAREA_WORDS;++i)
                if(i!=PROC_FINALIZE_OFFSET && u[i]!=(i==PROC_CRED_OFFSET?IDENTITY:0UL)) return 0;
        return raw_ok() && PROC_TRANSITION(&slots[SLOT]) &&
            VM_PDP6_BASE(&slots[SLOT])==BASE && mm_extent_count==3 &&
            MM_EXTENT_BASE(&mm_extents[1])==BASE && MM_EXTENT_WORDS(&mm_extents[1])==WORDS &&
            MM_EXTENT_TYPE(&mm_extents[1])==MM_TYPE_PROCESS && MM_EXTENT_OWNER(&mm_extents[1])==SLOT &&
            MM_EXTENT_PINS(&mm_extents[1])==1U &&
            mm_extents[0].span==((PROC_UAREA_WORDS<<18U)|UAREA) &&
            mm_extents[0].meta==(((kword_t)MM_TYPE_KERNEL_DYNAMIC<<MM_TYPE_SHIFT)|01001UL) &&
            mm_extents[2].span==((0200UL<<18U)|(BASE+WORDS)) &&
            mm_extents[2].meta==(((kword_t)MM_TYPE_PROCESS<<MM_TYPE_SHIFT)|2UL) &&
            records[SLOT].state==BACKING && proc_storage_expect_v30(SLOT,PROC_STORAGE_RESIDENT)==0 &&
            lease.vm_state==slots[SLOT].vm_state && lease.backing==BACKING &&
            lease.uarea==UAREA && lease.identity==IDENTITY;
}
static int raw_committed(void)
{
        return raw_ok() && !PROC_TRANSITION(&slots[SLOT]) &&
            !VM_PDP6_BASE(&slots[SLOT]) && u[PROC_SWAP_BACKING_OFFSET]==BACKING &&
            !u[PROC_FINALIZE_OFFSET] && u[PROC_CRED_OFFSET]==IDENTITY &&
            proc_storage_expect_v30(SLOT,PROC_STORAGE_PACKED)==0 &&
            mm_extent_count==3 && MM_EXTENT_BASE(&mm_extents[1])==SUFFIX &&
            MM_EXTENT_WORDS(&mm_extents[1])==RAW && MM_EXTENT_TYPE(&mm_extents[1])==MM_TYPE_PACKED_PROCESS &&
            !MM_EXTENT_PINS(&mm_extents[1]);
}
static int prepare(unsigned int slot)
{
        diag_rc_v1978=proc_pure_bitmap_prepare_v1978(slot,&lease);
        ++diag_cases_v1978;
        return (int)diag_rc_v1978;
}
static int cancel(void)
{
        diag_rc_v1978=proc_pure_bitmap_cancel_v1978(SLOT,&lease);
        ++diag_cases_v1978;
        return (int)diag_rc_v1978;
}

int main(void)
{
        unsigned int i,f;
        kword_t saved=mach_pi_disable(), oldtag, oldvm, oldcred, oldback, base;
        int rc, oldcount;
        /* Healthy SLEEP/STOP, exact candidate and RAW cancellation.
         * A later real allocation may reuse the released prefix. */
        for(f=0U;f<2U;++f) {
                diag_case_v1978=1U+f; reset(0U);
                if(f) slots[SLOT].sched=(kword_t)PROC_STOP<<PROC_STATE_SHIFT;
                if(prepare(SLOT)!=MM_OK || !candidate_ok() || bad_call || pin_calls!=1U ||
                    encode_calls!=1U || unpin_calls || rebase_calls) return 1;
                if(mm_free(BASE,MM_TYPE_PROCESS,SLOT)==MM_OK) return 2;
                if(legacy_gate_v1978(SLOT,PROC_STORAGE_RESIDENT)) return 030;
                /* A lost pin must not let old idle recovery unlock dirty text. */
                if(mm_unpin(BASE)!=MM_OK || legacy_gate_v1978(SLOT,PROC_STORAGE_RESIDENT) ||
                    !PROC_TRANSITION(&slots[SLOT]) || mm_pin(BASE)!=MM_OK) return 031;
                if(cancel()!=MM_OK || !raw_committed() || bad_call || rebase_calls!=1U || unpin_calls!=1U) return 3;
                if(cancel()!=MM_ERR_BUSY || !raw_committed()) return 4;
                /* Fill every other free gap. The real no-reclaim allocator
                 * must return the released prefix, not merely some free RAM. */
                mm_extents[3]=mm_extents[2]; mm_extents[2]=mm_extents[1];
                extent(1,UAREA+PROC_UAREA_WORDS,BASE-UAREA-PROC_UAREA_WORDS,
                    MM_TYPE_KERNEL_DYNAMIC,0701U);
                extent(4,BASE+WORDS+0200UL,mm_core_words-(BASE+WORDS+0200UL),
                    MM_TYPE_KERNEL_DYNAMIC,0702U);
                mm_extent_count=5;
                if(mm_alloc_aligned_noreclaim(PREFIX,02000UL,MM_TYPE_KERNEL_DYNAMIC,0700U,MM_ALLOC_HIGH,&base)!=MM_OK ||
                    base!=BASE) return 5;
                for(i=0U;i<PREFIX;++i) image[i]=GUARD ^ 077777UL;
                if(!raw_ok()) return 6;
        }
        for(f=1U;f<=2U;++f) {
                diag_case_v1978=010U+f; reset(f);
                rc=prepare(SLOT);
                if(rc!=(f==1U?PBM_NO_GAIN_V1975:MM_ERR_NOMEM) || !text_ok() ||
                    u[PROC_FINALIZE_OFFSET] || MM_EXTENT_PINS(&mm_extents[1]) ||
                    lease.vm_state!=GUARD || pin_calls!=1U || unpin_calls!=1U || bad_call) return 7;
                if(proc_pure_ram_drop_v1381(SLOT)!=MM_OK || !raw_committed() || bad_call) return 034;
        }
        /* Clean admission refusals cannot pin, write or change escrow. */
        for(f=0U;f<27U;++f) {
                diag_case_v1978=020U+f; reset(0U);
                switch(f) {
                case 0U: u[PROC_CRED_OFFSET]&=~PROC_SWAP_MUTABLE_V1976; break;
                case 1U: proc_current_slot=SLOT; break;
                case 2U: proc_rt_owner=SLOT; break;
                case 3U: proc_rt_owner=2UL; break;
                case 4U: PROC_CLEAR_TRANSITION(&slots[SLOT]); break;
                case 5U: slots[SLOT].sched=(kword_t)PROC_SRUN<<PROC_STATE_SHIFT; break;
                case 6U: u[PROC_FDCTL_OFFSET]=PROC_USER_MAP_BIT; break;
                case 7U: u[PROC_FDCTL_OFFSET]=PROC_FATAL_CLOSE_BIT; break;
                case 8U: u[PROC_FINALIZE_OFFSET]=GUARD; break;
                case 9U: u[PROC_SWAP_BACKING_OFFSET]=BACKING; break;
                case 10U: backstore_blocks=1UL; break;
                case 11U: roots[0]=0UL; break;
                case 12U: fs_memfs_service_jump=0UL; break;
                case 13U: records[SLOT].state=1UL; break;
                case 14U: mm_extents[1].meta|=(1UL<<MM_PIN_SHIFT); break;
                case 15U: mm_extents[1].meta^=3UL; break;
                case 16U: mm_extents[0].meta^=3UL; break;
                case 17U: mm_extents[0].span-=(1UL<<18U); break;
                case 18U: PROC_SET_META_LH(&slots[SLOT],BASE); break;
                case 19U: mm_extents[2].meta^=3UL; break;
                case 20U: mm_extents[2].span-=1UL; break;
                case 21U: proc_high_slot=SLOT; break;
                case 22U: modes[0]=2UL<<(SLOT*2U); break;
                case 23U: mm_extents[0].meta|=(1UL<<MM_PIN_SHIFT); break;
                case 24U: mm_extent_capacity=2U; break;
                case 25U: vfs_mount_root_base=0; break;
                case 26U: proc_slots=SLOT; break;
                }
                for(i=0U;i<3U;++i) before[i]=mm_extents[i];
                for(i=0U;i<PROC_UAREA_WORDS;++i) u_before[i]=u[i];
                oldtag=u[PROC_FINALIZE_OFFSET]; oldvm=slots[SLOT].vm_state;
                rc=prepare(SLOT);
                if(rc==MM_OK || !text_ok() || pin_calls || unpin_calls || encode_calls || rebase_calls || bad_call ||
                    u[PROC_FINALIZE_OFFSET]!=oldtag || slots[SLOT].vm_state!=oldvm || lease.vm_state!=GUARD) return 010;
                for(i=0U;i<3U;++i) if(before[i].span!=mm_extents[i].span || before[i].meta!=mm_extents[i].meta) return 011;
                for(i=0U;i<PROC_UAREA_WORDS;++i) if(u_before[i]!=u[i]) return 032;
        }
        /* Exact pin witness and lost replies. */
        for(f=1U;f<=4U;++f) {
                diag_case_v1978=060U+f; reset(0U);
                pin_fault=f==4U?2U:f;
                if(f==4U) unpin_fault=1U;
                if(prepare(SLOT)!=MM_ERR_BUSY || !text_ok() || encode_calls || rebase_calls || lease.vm_state!=GUARD || bad_call) return 012;
                if(f<=2U) {
                        if(u[PROC_FINALIZE_OFFSET] || MM_EXTENT_PINS(&mm_extents[1])) return 013;
                } else if(!u[PROC_FINALIZE_OFFSET] || !PROC_TRANSITION(&slots[SLOT]) || !MM_EXTENT_PINS(&mm_extents[1])) return 014;
        }
        /* Clean no-gain with lost unpin success vs retained pin. */
        for(f=1U;f<=2U;++f) {
                diag_case_v1978=070U+f; reset(1U); unpin_fault=f;
                if(prepare(SLOT)!=(f==1U?MM_ERR_BUSY:PBM_NO_GAIN_V1975) || !text_ok() || bad_call) return 015;
                if(f==1U?(!u[PROC_FINALIZE_OFFSET] || !MM_EXTENT_PINS(&mm_extents[1])):
                    (u[PROC_FINALIZE_OFFSET] || MM_EXTENT_PINS(&mm_extents[1]))) return 016;
        }
        /* Hard write fault: no valid candidate/count; no cancellation or
         * resident unlock is allowed. RAW remains unchanged in this injection. */
        diag_case_v1978=0100U; reset(0U); encode_fault=1U;
        if(prepare(SLOT)!=PBMD_WRITE_FAULT_V1977 || lease.vm_state!=GUARD || !raw_ok() || text_ok() ||
            u[PROC_FINALIZE_OFFSET]!=PROC_PURE_BITMAP_ESCROW_V1978(SUFFIX) || !MM_EXTENT_PINS(&mm_extents[1]) ||
            cancel()!=MM_ERR_BUSY || unpin_calls || rebase_calls || bad_call ||
            legacy_gate_v1978(SLOT,PROC_STORAGE_RESIDENT)) return 017;
        /* Cancellation checks the original identity, not a new owner. */
        for(f=0U;f<7U;++f) {
                diag_case_v1978=0110U+f; reset(0U);
                if(prepare(SLOT)!=MM_OK || !candidate_ok()) return 020;
                oldtag=u[PROC_FINALIZE_OFFSET]; oldvm=slots[SLOT].vm_state;
                oldcred=u[PROC_CRED_OFFSET]; oldback=records[SLOT].state;
                switch(f) {
                case 0U: lease.vm_state^=02000UL; break;
                case 1U: lease.uarea^=02000UL; break;
                case 2U: records[SLOT].state^=1UL; break;
                case 3U: u[PROC_CRED_OFFSET]^=PROC_SWAP_MUTABLE_V1976; break;
                case 4U: mm_extents[1].meta^=3UL; break;
                case 5U: u[PROC_FINALIZE_OFFSET]&=~MM_HALF_MASK; break;
                case 6U: u[PROC_FINALIZE_OFFSET]^=PROC_PURE_PREFIX_TAG_V1919; break;
                }
                if(cancel()!=MM_ERR_BUSY || rebase_calls || unpin_calls || !raw_ok() || !PROC_TRANSITION(&slots[SLOT])) return 021;
                lease.vm_state=oldvm; lease.uarea=UAREA; records[SLOT].state=oldback;
                u[PROC_CRED_OFFSET]=oldcred; u[PROC_FINALIZE_OFFSET]=oldtag;
                if(f==4U) mm_extents[1].meta^=3UL;
                if(cancel()!=MM_OK || !raw_committed()) return 022;
        }
        for(f=1U;f<=4U;++f) {
                diag_case_v1978=0130U+f; reset(0U);
                if(prepare(SLOT)!=MM_OK || !candidate_ok()) return 023;
                if(f<=2U) rebase_fault=f; else unpin_fault=f-2U;
                oldcount=mm_extent_count; oldtag=u[PROC_FINALIZE_OFFSET];
                rc=cancel();
                if(f==2U || f==4U) {
                        if(rc!=MM_OK || !raw_committed()) return 024;
                } else {
                        if(rc!=MM_ERR_BUSY || !raw_ok() || !PROC_TRANSITION(&slots[SLOT]) ||
                            u[PROC_FINALIZE_OFFSET]!=oldtag || mm_extent_count!=oldcount || !MM_EXTENT_PINS(&mm_extents[1])) return 025;
                        if(f==1U && (unpin_calls || VM_PDP6_BASE(&slots[SLOT])!=BASE ||
                            proc_storage_expect_v30(SLOT,PROC_STORAGE_RESIDENT))) return 026;
                        if(f==3U && (VM_PDP6_BASE(&slots[SLOT]) ||
                            proc_storage_expect_v30(SLOT,PROC_STORAGE_PACKED))) return 027;
                }
        }
        if(pi_state_v1978() & 0200UL) return 033;
        mach_pi_restore(saved);
        return 0;
}
