/* Real placed bitmap FULL and explicit deferred rollback; all MM
 * operations use original leaves except named test-only fault replies.
 * No idle service scheduling is simulated. */
#include "proc_pure_full_escrow_v1989.h"

#define F19_TARGET_UNPIN 1U
#define F19_TARGET_FREE 2U
#define F19_SOURCE_UNPIN 3U
#define F19_LOST_CLEANUP 4U
#define F19_SHORT_READ 5U
#define F19_SOURCE_REFUSE 6U
#define F19_SOURCE_FALSE 7U
#define F19_TARGET_FALSE 8U
#define F19_ALLOC_FALSE 9U
#define F19_ALLOC_BAD 10U
#define F19_FINISH_FALSE 11U
#define F19_FINISH_LOST 12U
#define F19_CODEC_HARD 13U
#define F19_LOAD_BRK 14U
#define F19_UNPIN_ID 15U
#define F19_ALLOC_LOST 16U
#define F19_NOFIT 17U
#define F19_FREE_FALSE 18U
#define F19_UNPIN_FALSE 19U

kword_t diag_case_v1989, diag_cases_v1989, diag_recover_v1989, diag_bad_v1989;
static unsigned int f19, pins19, unpins19, frees19, loads19, allocs19;
static unsigned int decodes19, verifies19, finishes19;
static kword_t words19, encoded19, heap19;
static unsigned int grown19;
static kword_t copy19[0400];

static kword_t value19(kword_t i)
{
        return grown19 ? (i%0100UL==0UL ? GUARD^i : 0UL) : raw_value(i);
}
static int payload19(void)
{
        kword_t i;
        for(i=0UL;i<encoded19;++i)
                if(low_v1985[i]!=copy19[i]) return 0;
        return 1;
}
static int full19(kword_t base)
{
        kword_t i,*dst=(kword_t *)base;
        for(i=0UL;i<PREFIX;++i)
                if(dst[i]!=(i<020UL?0UL:GUARD)) return 0;
        for(i=0UL;i<words19-PREFIX;++i)
                if(dst[PREFIX+i]!=value19(i)) return 0;
        return 1;
}
/* Independent oracle: do not use production packing/phase macros. */
static int escrow19(unsigned int phase,kword_t target)
{
        kword_t field=(u[PROC_BRK_OFFSET]>>18U)&01777UL;
        return u[PROC_FINALIZE_OFFSET]==((
#ifdef DAIMOS_PBM_IDLE_RECOVER_V1990
            (phase==1U?3UL:013UL)
#else
            013UL
#endif
            <<29U)|
            ((LOW_V1985>>7U)<<18U)|((kword_t)phase<<15U)|encoded19) &&
            field==(01000UL|(target>>10U)) &&
            (u[PROC_BRK_OFFSET]&~(01777UL<<18U))==heap19;
}
static void check_hold19(kword_t target)
{
        if(!escrow19(1U,target) || (pi_state_v1978()&0200UL) ||
            !PROC_TRANSITION(&slots[SLOT])) bad_call=050U;
}
int pin_v1989(kword_t base)
{
        ++pins19;
        check_hold19(base==LOW_V1985?0UL:target_addr);
        if(f19==F19_SOURCE_REFUSE && base==LOW_V1985) return MM_ERR_BUSY;
        if((f19==F19_SOURCE_FALSE && base==LOW_V1985) ||
            (f19==F19_TARGET_FALSE && base!=LOW_V1985)) return MM_OK;
        return mm_pin(base);
}
int alloc_v1989(kword_t words,kword_t align,unsigned int type,
    unsigned int owner,unsigned int pref,kword_t *out)
{
        int rc;
        ++allocs19;
        check_hold19(0UL);
        if(words!=words19 || align!=02000UL || type!=MM_TYPE_PROCESS ||
            owner!=SLOT || !MM_EXTENT_PINS(&mm_extents[1])) bad_call=051U;
        rc=mm_alloc_aligned_noreclaim(words,align,type,owner,pref,out);
        target_addr=*out;
        if(rc==MM_OK) {
                if(f19==F19_ALLOC_FALSE) *out=0UL;
                if(f19==F19_ALLOC_BAD) *out|=1UL;
                if(f19==F19_ALLOC_LOST) return MM_ERR_NOMEM;
        }
        return rc;
}
int unpin_v1989(kword_t base)
{
        int rc;
        ++unpins19;
        check_hold19(base==LOW_V1985?0UL:target_addr);
        if(f19==F19_TARGET_UNPIN && base==target_addr) return MM_ERR_BUSY;
        if(f19==F19_SOURCE_UNPIN && base==LOW_V1985) return MM_ERR_BUSY;
        if(f19==F19_UNPIN_FALSE && base==target_addr) return MM_OK;
        rc=mm_unpin(base);
        if(f19==F19_UNPIN_ID && base==target_addr) {
                /* Coherent-looking but changed backing after mutation:
                 * authority must remain revoked even after repair. */
                records[SLOT].state^=1UL;
                u[PROC_SWAP_BACKING_OFFSET]=records[SLOT].state;
        }
        return f19==F19_LOST_CLEANUP?MM_ERR_BUSY:rc;
}
int free_v1989(kword_t base,unsigned int kind,unsigned int owner)
{
        int rc;
        if(kind==MM_TYPE_PACKED_PROCESS)
                return term_free_v1982(base,kind,owner);
        ++frees19;
        check_hold19(target_addr);
        if(base!=target_addr || kind!=MM_TYPE_PROCESS || owner!=SLOT) bad_call=052U;
        if(f19==F19_TARGET_FREE) return MM_ERR_BUSY;
        if(f19==F19_FREE_FALSE) return MM_OK;
        rc=mm_free(base,kind,owner);
        return f19==F19_LOST_CLEANUP?MM_ERR_BUSY:rc;
}
static int load19(kword_t backing,kword_t target,kword_t area,kword_t words)
{
        int rc;
        ++loads19;
        if(backing!=BACKING || target!=target_addr || area!=UAREA ||
            words!=words19 || !(pi_state_v1978()&0200UL) ||
            !escrow19(1U,target) || !payload19()) bad_call=053U;
        rc=exec_image_full_bounded_v1391(backing,target,area,words);
        if(f19==F19_LOAD_BRK) u[PROC_BRK_OFFSET]^=1UL;
        if(f19==F19_TARGET_UNPIN || f19==F19_TARGET_FREE ||
            f19==F19_SOURCE_UNPIN || f19==F19_LOST_CLEANUP ||
            f19==F19_UNPIN_ID || f19==F19_FREE_FALSE || f19==F19_UNPIN_FALSE)
                return -1;
        return rc;
}
int decode_v1989(kword_t source,kword_t encoded,kword_t target,
    kword_t raw,unsigned int direction)
{
        int rc;
        ++decodes19;
        if(source!=LOW_V1985 || encoded!=encoded19 ||
            target!=target_addr+PREFIX || raw!=words19-PREFIX ||
            !(pi_state_v1978()&0200UL)) bad_call=054U;
        rc=pbmd_decode_v1977(source,encoded,target,raw,direction);
        return f19==F19_CODEC_HARD && rc==MM_OK?PBMD_WRITE_FAULT_V1977:rc;
}
int verify_v1989(kword_t base,kword_t raw,kword_t source,kword_t encoded)
{
        ++verifies19;
        if(base!=target_addr+PREFIX || raw!=words19-PREFIX ||
            source!=LOW_V1985 || encoded!=encoded19 ||
            !(pi_state_v1978()&0200UL)) bad_call=055U;
        return pbmd_verify_v1979(base,raw,source,encoded);
}
int finish_v1989(unsigned int slot,kword_t source,kword_t encoded,
    kword_t target,kword_t words)
{
        int rc;
        ++finishes19;
        check_hold19(target);
        if(slot!=SLOT || source!=LOW_V1985 || encoded!=encoded19 ||
            target!=target_addr || words!=words19 || !full19(target) ||
            !payload19()) bad_call=056U;
        if(f19==F19_FINISH_FALSE) return MM_OK;
        rc=mm_pure_bitmap_finish_v1664(slot,source,encoded,target,words);
        return f19==F19_FINISH_LOST?MM_ERR_BUSY:rc;
}

static int setup19(unsigned int grown)
{
        kword_t i, *raw=(kword_t *)060000UL;
        reset17();
        if(drop17() || !placed17()) return 0;
        grown19=grown; words19=WORDS; encoded19=PACKED_WORDS;
        heap19=(WORDS<<18U)|WORDS;
        if(grown) {
                /* Explicit independently constructed larger VM fixture;
                 * real codec creates its bitmap in the original free gap.
                 * The logical heap floor is the original initial APR. */
                words19=04000UL; heap19=(WORDS<<18U)|02001UL;
                for(i=0UL;i<words19-PREFIX;++i) raw[i]=value19(i);
                if(pbmd_encode_v1977(060000UL,words19-PREFIX,
                    LOW_V1985,PREFIX,PBMD_FORWARD_V1977,&encoded19)!=MM_OK) return 0;
                extent(1,LOW_V1985,encoded19,MM_TYPE_PACKED_PROCESS,SLOT);
                VM_PDP6_SET_SPACE(&slots[SLOT],words19,0UL);
        }
        for(i=0UL;i<encoded19;++i) copy19[i]=low_v1985[i];
        u[PROC_BRK_OFFSET]=heap19;
        PROC_SET_TRANSITION(&slots[SLOT]);
        slots[SLOT].sched=(kword_t)PROC_SRUN<<PROC_STATE_SHIFT;
        f19=pins19=unpins19=frees19=loads19=allocs19=decodes19=verifies19=finishes19=0U;
        return 1;
}
static int restore19(void)
{
        int rc;
        ++diag_cases_v1989;
        mach_pi_restore(0200UL);
        rc=proc_pure_bitmap_restore_v1980(SLOT,load19);
        if(!(pi_state_v1978()&0200UL)) bad_call=057U;
        (void)mach_pi_disable();
        diag_bad_v1989=bad_call;
        return rc;
}
static int recover19(void)
{
        int rc;
        ++diag_recover_v1989;
        mach_pi_restore(0200UL);
        rc=proc_pure_bitmap_recover_v1989(SLOT);
        if(!(pi_state_v1978()&0200UL)) bad_call=060U;
        (void)mach_pi_disable();
        diag_bad_v1989=bad_call;
        return rc;
}
static int clean19(unsigned int transition)
{
        return !bad_call && payload19() &&
            !!PROC_TRANSITION(&slots[SLOT])==transition &&
            !VM_PDP6_BASE(&slots[SLOT]) && modes[0]==MODE3_V1985 &&
            VM_SPACE_WORDS(&slots[SLOT])==words19 &&
            u[PROC_BRK_OFFSET]==heap19 && !u[PROC_FINALIZE_OFFSET] &&
            u[PROC_SWAP_BACKING_OFFSET]==BACKING && records[SLOT].state==BACKING &&
            u[PROC_CRED_OFFSET]==IDENTITY &&
            proc_pure_full_owners_v1917(SLOT,LOW_V1985,encoded19,0UL,words19,0U,0U)==1;
}
static int held19(unsigned int phase,kword_t target)
{
        return !bad_call && PROC_TRANSITION(&slots[SLOT]) &&
            !VM_PDP6_BASE(&slots[SLOT]) && modes[0]==MODE3_V1985 &&
            escrow19(phase,target) && payload19();
}
static int resident19(void)
{
        return !bad_call && !PROC_TRANSITION(&slots[SLOT]) &&
            VM_PDP6_BASE(&slots[SLOT])==target_addr && full19(target_addr) &&
            u[PROC_BRK_OFFSET]==heap19 && !u[PROC_FINALIZE_OFFSET] &&
            !u[PROC_SWAP_BACKING_OFFSET] && modes[0]==(1UL<<6U) &&
            proc_pure_full_owners_v1917(SLOT,LOW_V1985,encoded19,
                target_addr,words19,0U,0U)==2;
}

int main(void)
{
        unsigned int f,g,i,n,unpins,frees,pins,allocs,loads,decodes,verifies,finishes;
        kword_t saved=mach_pi_disable(),tag,brk,oldspan,oldmeta,b;
        struct mm_extent table[5];
        int rc;
        install_d6_v1980();
        for(g=0U;g<2U;++g) {
                /* Real full success, lost atomic finish reply, clean
                 * read/pin/allocation refusal and lost cleanup replies. */
                for(f=0U;f<=F19_UNPIN_FALSE;++f) {
                        diag_case_v1989=(g<<6U)|f;
                        if(!setup19(g)) return 1;
                        f19=f; fault=f==F19_SHORT_READ?2U:0U;
                        if(f==F19_NOFIT) mm_extent_capacity=mm_extent_count;
                        rc=restore19();
                        if(bad_call) return 2;
                        if(!f || f==F19_FINISH_LOST) {
                                if(rc!=MM_OK || !resident19()) return 3;
                                continue;
                        }
                        if(f==F19_LOST_CLEANUP || f==F19_SHORT_READ ||
                            f==F19_SOURCE_REFUSE || f==F19_ALLOC_LOST || f==F19_NOFIT) {
                                if(rc==MM_OK || !clean19(1U) ||
                                    proc_pure_bitmap_unlock_v1981(SLOT) || !clean19(0U)) return 4;
                                continue;
                        }
                        if(rc!=MM_ERR_BUSY || !PROC_TRANSITION(&slots[SLOT])) return 5;
                        if(f<=F19_SOURCE_UNPIN || f==F19_FREE_FALSE || f==F19_UNPIN_FALSE) {
                                unsigned int phase=f==F19_SOURCE_UNPIN?4U:
                                    (f==F19_TARGET_FREE || f==F19_FREE_FALSE?3U:2U);
                                if(!held19(phase,phase==4U?0UL:target_addr)) return 6;
                                if(recover19()!=MM_ERR_BUSY ||
                                    !held19(phase,phase==4U?0UL:target_addr)) return 7;
                                /* Missing mount cannot obstruct bounded
                                 * rollback of the exact old source. */
                                roots[0]=0UL; f19=0U; fault=0U;
                                pins=pins19; allocs=allocs19; loads=loads19;
                                decodes=decodes19; verifies=verifies19; finishes=finishes19;
                                if(recover19()!=MM_OK || !clean19(0U) ||
                                    pins19!=pins || allocs19!=allocs || loads19!=loads ||
                                    decodes19!=decodes || verifies19!=verifies || finishes19!=finishes) return 010;
                                if(recover19()!=MM_ERR_BUSY) return 011;
                                /* Normal restoration can now retry. */
                                roots[0]=VFS_NODE(MEMFS_PROVIDER,VFS_MOUNT_KIND(1U,1U),1U);
                                PROC_SET_TRANSITION(&slots[SLOT]);
                                if(restore19()!=MM_OK || !resident19()) return 012;
                        } else {
                                if(((u[PROC_FINALIZE_OFFSET]>>15U)&7UL)!=1UL) return 013;
                                /* Unknown outcomes must not perform any
                                 * subsequent release, even before a retry. */
                                if(frees19 || unpins19!=(f==F19_UNPIN_ID?1U:0U))
                                        return 036;
                                if(f==F19_SOURCE_FALSE) {
                                        if(allocs19 || loads19 ||
                                            proc_pure_full_owners_v1917(SLOT,LOW_V1985,
                                                encoded19,0UL,words19,0U,0U)!=1) return 037;
                                } else {
                                        unsigned int tp=(f==F19_TARGET_FALSE ||
                                            f==F19_ALLOC_FALSE || f==F19_ALLOC_BAD ||
                                            f==F19_UNPIN_ID)?0U:1U;
                                        if(proc_pure_full_owners_v1917(SLOT,LOW_V1985,
                                            encoded19,target_addr,words19,1U,tp)!=3) return 040;
                                        if((f==F19_ALLOC_FALSE || f==F19_ALLOC_BAD) &&
                                            ((u[PROC_BRK_OFFSET]>>18U)&01777UL)!=01400UL) return 041;
                                }
                                unpins=unpins19; frees=frees19; tag=u[PROC_FINALIZE_OFFSET];
                                brk=u[PROC_BRK_OFFSET];
                                if(recover19()!=MM_ERR_BUSY || unpins19!=unpins ||
                                    frees19!=frees || tag!=u[PROC_FINALIZE_OFFSET] ||
                                    brk!=u[PROC_BRK_OFFSET]) return 014;
                                if(f==F19_UNPIN_ID) {
                                        records[SLOT].state=BACKING;
                                        u[PROC_SWAP_BACKING_OFFSET]=BACKING;
                                        if(recover19()!=MM_ERR_BUSY || !held19(1U,target_addr) ||
                                            unpins19!=unpins || frees19!=frees) return 035;
                                }
                        }
                }
        }
        /* A delayed retry must use the original exact source length,
         * never infer ownership from a changed live descriptor. */
        for(f=0U;f<18U;++f) {
                diag_case_v1989=0200U+f;
                if(!setup19(1U)) return 015;
                f19=F19_TARGET_UNPIN;
                if(restore19()!=MM_ERR_BUSY || !held19(2U,target_addr)) return 016;
                oldspan=mm_extents[1].span; oldmeta=mm_extents[1].meta;
                switch(f) {
                case 0: mm_extents[1].span+=1UL<<18U; break;
                case 1: mm_extents[1].span-=1UL<<18U; break;
                case 2: mm_extents[1].span+=0200UL; break;
                case 3: mm_extents[1].meta+=1UL<<MM_PIN_SHIFT; break;
                case 4: mm_extents[1].meta-=1UL<<MM_PIN_SHIFT; break;
                case 5: mm_extents[1].meta^=3UL; break;
                case 6: mm_extents[3].span-=1UL<<18U; break;
                case 7: mm_extents[3].meta+=1UL<<MM_PIN_SHIFT; break;
                case 8: mm_extents[3].meta-=1UL<<MM_PIN_SHIFT; break;
                case 9: mm_extents[3].meta^=3UL; break;
                case 10: /* Lost source with sole target; never publish. */
                        mm_extents[1]=mm_extents[2]; mm_extents[2]=mm_extents[3]; --mm_extent_count; break;
                case 11: u[PROC_BRK_OFFSET]^=01000UL<<18U; break;
                case 12: u[PROC_BRK_OFFSET]|=0400UL<<18U; break;
                case 13: u[PROC_FINALIZE_OFFSET]|=PROC_FINALIZE_MARK; break;
                case 14: u[PROC_SWAP_BACKING_OFFSET]^=1UL; break;
                case 15: u[PROC_CRED_OFFSET]^=PROC_SWAP_MUTABLE_V1976; break;
                case 16: u[PROC_FDCTL_OFFSET]|=PROC_USER_MAP_BIT; break;
                case 17: proc_current_slot=2UL; break;
                }
                n=mm_extent_count;
                for(i=0U;i<n;++i) table[i]=mm_extents[i];
                unpins=unpins19; frees=frees19;
                f19=0U;
                if(recover19()!=MM_ERR_BUSY || !PROC_TRANSITION(&slots[SLOT]) ||
                    VM_PDP6_BASE(&slots[SLOT]) || unpins19!=unpins || frees19!=frees ||
                    mm_extent_count!=n || !payload19()) return 017;
                for(i=0U;i<n;++i)
                        if(table[i].span!=mm_extents[i].span || table[i].meta!=mm_extents[i].meta) return 020;
                if(f<10U && ((u[PROC_FINALIZE_OFFSET]>>15U)&7UL)!=1UL) return 021;
                if(f==0U) {
                        /* Even repairing the deliberately changed span
                         * cannot reinstate authority revoked by the retry. */
                        mm_extents[1].span=oldspan; mm_extents[1].meta=oldmeta;
                        if(recover19()!=MM_ERR_BUSY || !held19(1U,target_addr)) return 022;
                }
        }
        /* Check the other two rollback phases independently. Neither
         * a missing target nor a changed source authorizes cleanup. */
        for(g=0U;g<2U;++g) {
                for(f=0U;f<6U;++f) {
                        diag_case_v1989=0300U+g*010U+f;
                        if(!setup19(1U)) return 031;
                        f19=g?F19_SOURCE_UNPIN:F19_TARGET_FREE;
                        if(restore19()!=MM_ERR_BUSY ||
                            !held19(g?4U:3U,g?0UL:target_addr)) return 032;
                        switch(f) {
                        case 0: mm_extents[1].span+=1UL<<18U; break;
                        case 1: mm_extents[1].meta+=1UL<<MM_PIN_SHIFT; break;
                        case 2: mm_extents[1].meta-=1UL<<MM_PIN_SHIFT; break;
                        case 3: /* Same interval, foreign packed owner. */
                                mm_extents[1].meta^=3UL; break;
                        case 4:
                                if(g) { /* Foreign overlap, old source lost. */
                                        mm_extents[1].meta=((kword_t)MM_TYPE_KERNEL_DYNAMIC<<18U)|0700UL;
                                } else {
                                        /* Old target disappeared without our proof. */
                                        --mm_extent_count;
                                }
                                break;
                        case 5:
                                if(g) { /* Lost original bitmap, no target. */
                                        mm_extents[1]=mm_extents[2]; --mm_extent_count;
                                } else {
                                        /* Foreign overlap at old target. */
                                        mm_extents[3].meta=((kword_t)MM_TYPE_KERNEL_DYNAMIC<<18U)|0700UL;
                                }
                                break;
                        }
                        n=mm_extent_count;
                        for(i=0U;i<n;++i) table[i]=mm_extents[i];
                        unpins=unpins19; frees=frees19; f19=0U;
                        if(recover19()!=MM_ERR_BUSY || !PROC_TRANSITION(&slots[SLOT]) ||
                            VM_PDP6_BASE(&slots[SLOT]) || unpins19!=unpins || frees19!=frees ||
                            mm_extent_count!=n || !payload19() ||
                            ((u[PROC_FINALIZE_OFFSET]>>15U)&7UL)!=1UL) return 033;
                        for(i=0U;i<n;++i)
                                if(table[i].span!=mm_extents[i].span || table[i].meta!=mm_extents[i].meta) return 034;
                }
        }
        /* Source-only retry after exact target retirement must not touch
         * that address once the real allocator has reused it. */
        diag_case_v1989=0240U;
        if(!setup19(0U)) return 023;
        f19=F19_SOURCE_UNPIN;
        if(restore19()!=MM_ERR_BUSY || !held19(4U,0UL)) return 024;
        if(mm_alloc_aligned_noreclaim(words19,02000UL,MM_TYPE_KERNEL_DYNAMIC,
            0700U,MM_ALLOC_HIGH,&b)!=MM_OK || b!=target_addr) return 025;
        *(kword_t *)b=GUARD;
        f19=0U;
        if(recover19()!=MM_OK || !clean19(0U) || *(kword_t *)b!=GUARD) return 026;
        /* Do not borrow heap bits on an invalid ordinary BRK. */
        diag_case_v1989=0241U;
        if(!setup19(1U)) return 027;
        u[PROC_BRK_OFFSET]|=1UL<<18U;
        brk=u[PROC_BRK_OFFSET];
        if(restore19()==MM_OK || pins19 || allocs19 ||
            u[PROC_BRK_OFFSET]!=brk || u[PROC_FINALIZE_OFFSET] ||
            proc_pure_bitmap_unlock_v1981(SLOT)==MM_OK || bad_call) return 030;
        mach_pi_restore(saved);
        return 0;
}
