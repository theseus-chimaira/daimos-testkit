/* Appended to the unchanged v1978/v1979 fixtures. Real DROP, bounded
 * DXR loader, fixed block codec, directory decoder, MM and PI execute. */
#include "proc_pure_bitmap_restore_v1980.h"
#include "exec.h"
#define INIT_WORDS (TEXT+040UL)
#define DXR_NODE VFS_NODE(MEMFS_PROVIDER,VFS_MOUNT_KIND(1U,1U),012345UL)
#define TARGET 076000UL
kword_t diag_case_v1980, diag_cases_v1980, diag_rc_v1980, diag_bad_v1980;
static unsigned int fault, loads, payload_reads, finish_calls, alloc_calls;
static unsigned int restore_pins, restore_unpins, restore_frees, decode_calls, verify_calls;
static kword_t packed_copy[PACKED_WORDS];
static kword_t target_addr;
extern int exec_image_full_bounded_v1391(kword_t,kword_t,kword_t,kword_t);
extern int mm_pure_bitmap_finish_v1664(unsigned int,kword_t,kword_t,kword_t,kword_t);
extern void install_d6_v1980(void);

static int packed_ok(void)
{
        unsigned int i;
        for(i=0U;i<PACKED_WORDS;++i) if(image[i]!=packed_copy[i]) return 0;
        return 1;
}
static int full_ok(kword_t target)
{
        kword_t *dst=(kword_t *)(unsigned long)target;
        unsigned int i;
        for(i=0U;i<PREFIX;++i) if(dst[i]!=(i<020U?0UL:GUARD)) return 0;
        for(i=0U;i<RAW;++i) if(dst[PREFIX+i]!=raw_value(i)) return 0;
        return 1;
}
static int compressed_backing(void) { return fault==1U || fault==28U; }
static kword_t initialized(void) { return fault==3U ? WORDS+1UL : INIT_WORDS; }
int vfs_stat(vnode_t node,struct vfs_stat *st)
{
        if(node!=DXR_NODE) return -1;
        st->type=VFS_TYPE_REG; st->mode=0U; st->reserved=0UL;
        st->size_words=3UL+(compressed_backing()?5UL:initialized())+(initialized()+35UL)/36UL;
        st->uid=st->gid=0U; st->mtime=0UL;
        return 0;
}
int vfs_read_words(vnode_t node,unsigned int off,kword_t *buf,unsigned int count)
{
        unsigned int i;
        if(node!=DXR_NODE) return -1;
        if(off==0U && count==2U) {
                buf[0]=0447062UL<<18U;
                buf[1]=(initialized()<<18U)|EXEC_DXR_F_PURE|
                    (compressed_backing()?EXEC_DXR_F_COMPRESSED:0UL);
                return 2;
        }
        if(off==2U && count==1U) {
                buf[0]=((TEXT|0400000UL)<<18U)|EXEC_DXR_TEXT_TAG;
                return 1;
        }
        if(off==3U && compressed_backing() && count==5U) {
                ++payload_reads;
                /* One literal followed by three distance-1 match runs.
                 * 1+128+128+95 = 352 initialized words. Real codec. */
                buf[0]=0UL; buf[1]=GUARD;
                buf[2]=buf[3]=(2UL<<34U)|(127UL<<27U);
                buf[4]=(2UL<<34U)|(94UL<<27U);
                if(fault==28U) buf[4]|=1UL; /* malformed reserved field */
                return 5;
        }
        if(off==3U && count==initialized() && !compressed_backing()) {
                ++payload_reads;
                if(buf!=(kword_t *)(unsigned long)(target_addr+020UL)) return -1;
                for(i=0U;i<count;++i) {
                        buf[i]=GUARD;
                        if(fault==2U && i==010U) return (int)i;
                }
                if(fault==4U) roots[0]^=1UL<<VFS_PROVIDER_SHIFT;
                return (int)count;
        }
        return -1;
}
int alloc_v1980(kword_t words,kword_t align,unsigned int type,unsigned int owner,
    unsigned int pref,kword_t *out)
{
        int rc;
        ++alloc_calls;
        if(words!=WORDS || align!=02000UL || type!=MM_TYPE_PROCESS || owner!=SLOT ||
            !MM_EXTENT_PINS(&mm_extents[1]) || (pi_state_v1978()&0200UL)) bad_call=010U;
        rc=mm_alloc_aligned_noreclaim(words,align,type,owner,pref,out);
        target_addr=*out;
        if(fault==29U && rc==MM_OK) return MM_ERR_NOMEM; /* lost alloc reply */
        if(fault==30U && rc==MM_OK) { *out=0UL; return MM_OK; }
        return rc;
}
int pin_v1980(kword_t base)
{
        int rc;
        ++restore_pins;
        if(pi_state_v1978()&0200UL) bad_call=011U;
        if((fault==9U && base!=BASE)||(fault==10U && base==BASE)) return MM_ERR_BUSY;
        if((fault==33U && base==BASE)||(fault==34U && base!=BASE)) return MM_OK;
        rc=mm_pin(base);
        if((fault==11U && base==BASE)||(fault==12U && base!=BASE)) return MM_ERR_BUSY;
        return rc;
}
int unpin_v1980(kword_t base)
{
        int rc;
        ++restore_unpins;
        if(pi_state_v1978()&0200UL) bad_call=012U;
        if((fault==23U && base==target_addr)||(fault==31U && base==BASE)) return MM_ERR_BUSY;
        rc=mm_unpin(base);
        if(fault==24U) return MM_ERR_BUSY;
        return rc;
}
int free_v1980(kword_t base,unsigned int kind,unsigned int owner)
{
        int rc;
        ++restore_frees;
        if(base==BASE || kind!=MM_TYPE_PROCESS || owner!=SLOT || (pi_state_v1978()&0200UL)) bad_call=013U;
        if(fault==21U) return MM_ERR_BUSY;
        rc=mm_free(base,kind,owner);
        return fault==22U ? MM_ERR_BUSY:rc;
}
static int load_v1980(kword_t backing,kword_t target,kword_t area,kword_t words)
{
        int rc;
        ++loads;
        if(backing!=BACKING || target!=target_addr || area!=UAREA || words!=WORDS ||
            !(pi_state_v1978()&0200UL) || !packed_ok() ||
            proc_pure_full_owners_v1917(SLOT,BASE,PACKED_WORDS-(fault==6U),target,WORDS,1U,1U)!=3 ||
            u[PROC_FINALIZE_OFFSET]!=PROC_PURE_BITMAP_FULL_V1980(BASE,target)) bad_call=014U;
        rc=exec_image_full_bounded_v1391(backing,target,area,words);
        if(fault==16U) mm_extents[3].meta+=1UL<<MM_PIN_SHIFT;
        if(fault==17U) mm_extents[3].meta^=3UL;
        if(fault==18U) records[SLOT].state^=1UL;
        if(fault==19U) mm_extents[0].meta^=3UL;
        if(fault==20U) modes[0]&=~(3UL<<(2U*SLOT));
        if(fault==35U) u[PROC_FINALIZE_OFFSET]^=1UL;
        if(fault==36U) u[PROC_CRED_OFFSET]^=PROC_SWAP_MUTABLE_V1976;
        if(fault==37U) mm_extents[1].meta^=3UL;
        if(fault==38U) mm_extents[2].span=(0200UL<<18U)|(BASE+PACKED_WORDS-1UL);
        if(fault==21U || fault==22U || fault==23U || fault==24U || fault==31U) return -1;
        return rc;
}
int decode_v1980(kword_t source,kword_t encoded,kword_t dest,kword_t raw,unsigned int direction)
{
        int rc;
        ++decode_calls;
        if(source!=BASE || dest!=target_addr+PREFIX || raw!=RAW ||
            !(pi_state_v1978()&0200UL)) bad_call=015U;
        rc=pbmd_decode_v1977(source,encoded,dest,raw,direction);
        if(fault==25U && rc==MM_OK) *(kword_t *)(unsigned long)dest^=1UL;
        if(fault==26U && rc==MM_OK) return PBMD_WRITE_FAULT_V1977;
        return rc;
}
int verify_v1980(kword_t raw_base,kword_t raw_words,kword_t packed_base,kword_t packed_words)
{
        ++verify_calls;
        if(raw_base!=target_addr+PREFIX || raw_words!=RAW || packed_base!=BASE ||
            packed_words!=PACKED_WORDS || !(pi_state_v1978()&0200UL)) bad_call=020U;
        return pbmd_verify_v1979(raw_base,raw_words,packed_base,packed_words);
}
int finish_v1980(unsigned int slot,kword_t source,kword_t encoded,kword_t target,kword_t words)
{
        int rc;
        ++finish_calls;
        if(slot!=SLOT || source!=BASE || encoded!=PACKED_WORDS || target!=target_addr || words!=WORDS ||
            (pi_state_v1978()&0200UL) || !full_ok(target) || !packed_ok() ||
            proc_pure_full_owners_v1917(slot,source,encoded,target,words,1U,1U)!=3) bad_call=016U;
        if(fault==13U) return MM_ERR_BUSY;
        if(fault==15U) return MM_OK;
        rc=mm_pure_bitmap_finish_v1664(slot,source,encoded,target,words);
        if(fault==27U && rc==MM_OK) mm_extents[2].meta^=3UL;
        if(fault==39U && rc==MM_OK) records[SLOT].state^=1UL;
        return fault==14U || fault==27U ? MM_ERR_BUSY:rc;
}
static int setup14(void)
{
        unsigned int i;
        reset13(0U);
        if(prepare(SLOT)!=MM_OK || commit13()!=MM_OK || !bitmap_ok()) return 0;
        for(i=0U;i<PACKED_WORDS;++i) packed_copy[i]=image[i];
        for(i=PACKED_WORDS;i<WORDS;++i) image[i]=GUARD^077777UL;
        PROC_SET_TRANSITION(&slots[SLOT]);
        slots[SLOT].sched=(kword_t)PROC_SRUN<<PROC_STATE_SHIFT;
        loads=payload_reads=finish_calls=alloc_calls=restore_pins=restore_unpins=restore_frees=decode_calls=0U;
        target_addr=0UL; bad_call=verify_calls=0U;
        for(i=0U;i<WORDS;++i) ((kword_t *)TARGET)[i]=GUARD^01234UL;
        ((kword_t *)TARGET)[-1]=GUARD^04321UL;
        return 1;
}
static int restore14(void)
{
        int rc;
        ++diag_cases_v1980;
        mach_pi_restore(0200UL);
        rc=proc_pure_bitmap_restore_v1980(SLOT,load_v1980);
        diag_rc_v1980=(kword_t)rc;
        if(!(pi_state_v1978()&0200UL)) bad_call=017U;
        (void)mach_pi_disable();
        return rc;
}
static int clean14(void)
{
        return packed_ok() && PROC_TRANSITION(&slots[SLOT]) && !VM_PDP6_BASE(&slots[SLOT]) &&
            modes[0]==((1UL<<6U)|(3UL<<(2U*SLOT))) && !u[PROC_FINALIZE_OFFSET] &&
            u[PROC_SWAP_BACKING_OFFSET]==BACKING && mm_extent_count==3 &&
            MM_EXTENT_PINS(&mm_extents[1])==0U && mm_extents[1].span==((PACKED_WORDS<<18U)|BASE) &&
            MM_EXTENT_OWNER(&mm_extents[1])==SLOT && MM_EXTENT_TYPE(&mm_extents[1])==MM_TYPE_PACKED_PROCESS;
}
int main(void)
{
        unsigned int f,i;
        kword_t pi=mach_pi_disable(), b;
        int rc;
        install_d6_v1980();
        for(f=0U;f<=39U;++f) {
                diag_case_v1980=f; fault=f;
                if(!setup14()) return 1;
                if(f==5U) image[21]|=1UL;
                if(f==6U) mm_extents[1].span-=1UL<<18U;
                if(f==7U) image[22]=0UL;
                if(f==8U) fill_arenas(); /* actual no-reclaim pressure */
                if(f==32U) mm_extent_capacity=3U; /* actual descriptor exhaustion */
                if(f==5U || f==7U) for(i=0U;i<PACKED_WORDS;++i) packed_copy[i]=image[i];
                rc=restore14();
                diag_bad_v1980=bad_call;
                if(bad_call) return 2;
                if(f==0U || f==1U || f==11U || f==12U || f==14U) {
                        if(rc!=MM_OK || target_addr!=TARGET || !full_ok(TARGET) ||
                            PROC_TRANSITION(&slots[SLOT]) || VM_PDP6_BASE(&slots[SLOT])!=TARGET ||
                            u[PROC_FINALIZE_OFFSET] || u[PROC_SWAP_BACKING_OFFSET] ||
                            u[PROC_CRED_OFFSET]!=IDENTITY || modes[0]!=(1UL<<6U) ||
                            mm_extent_count!=3 || MM_EXTENT_BASE(&mm_extents[2])!=TARGET ||
                            MM_EXTENT_PINS(&mm_extents[2]) || finish_calls!=1U || verify_calls!=1U || restore_unpins || restore_frees) return 3;
                        /* The former encoded owner is now unowned and can
                         * be overwritten without changing the runnable APR. */
                        fill_arenas();
                        mm_arena_count=3;
                        mm_arenas[2]=(WORDS<<18U)|TARGET;
                        if(mm_alloc_aligned_noreclaim(PACKED_WORDS,02000UL,MM_TYPE_KERNEL_DYNAMIC,0700U,MM_ALLOC_LOW,&b)!=MM_OK || b!=BASE) return 4;
                        for(i=0U;i<PACKED_WORDS;++i) image[i]=GUARD;
                        if(!full_ok(TARGET)) return 5;
                } else if((f>=15U && f<=21U) || f==23U || f==26U || f==27U || f==30U || f==31U || (f>=33U && f<=39U)) {
                        if(rc!=MM_ERR_BUSY || !PROC_TRANSITION(&slots[SLOT]) || !u[PROC_FINALIZE_OFFSET] ||
                            VM_PDP6_BASE(&slots[SLOT]) || !packed_ok()) return 6;
                        if(f>=15U && f<=20U && (restore_unpins || restore_frees)) return 7;
                        if(((f>=16U && f<=20U) || (f>=33U && f<=38U)) && (decode_calls || finish_calls)) return 010;
                        if(f==21U && (mm_extent_count!=4 || !MM_EXTENT_PINS(&mm_extents[1]) ||
                            MM_EXTENT_PINS(&mm_extents[3]) || restore_unpins!=1U || restore_frees!=1U)) return 021;
                        if(f==23U && (mm_extent_count!=4 || !MM_EXTENT_PINS(&mm_extents[1]) ||
                            !MM_EXTENT_PINS(&mm_extents[3]) || restore_frees)) return 022;
                        if(f==31U && (mm_extent_count!=3 || !MM_EXTENT_PINS(&mm_extents[1]) ||
                            u[PROC_FINALIZE_OFFSET]!=PROC_PURE_BITMAP_FULL_V1980(BASE,0UL))) return 023;
                        if(f==33U && (mm_extent_count!=3 || alloc_calls || restore_unpins || restore_frees)) return 024;
                        if(f==34U && (mm_extent_count!=4 || loads || restore_unpins || restore_frees)) return 025;
                } else {
                        if(rc==MM_OK || !clean14()) {
                                /* The truncated descriptor is intentionally
                                 * still authoritative after clean refusal. */
                                if(f!=6U || rc==MM_OK || u[PROC_FINALIZE_OFFSET] ||
                                    MM_EXTENT_WORDS(&mm_extents[1])!=PACKED_WORDS-1UL ||
                                    MM_EXTENT_PINS(&mm_extents[1]) || !packed_ok()) return 011;
                        }
                        if(f==3U && payload_reads) return 012;
                        if((f==8U || f==9U || f==10U || f==29U || f==32U) && loads) return 013;
                        if(f!=13U && finish_calls) return 014;
                        if(f==8U && rc!=MM_ERR_NOMEM) return 026;
                        if(f==32U && rc!=MM_ERR_DESCRIPTORS) return 027;
                }
                if(image[-1]!=GUARD || ((kword_t *)TARGET)[-1]!=(GUARD^04321UL)) return 015;
                for(i=0U;i<0200U;++i) if(image[WORDS+i]!=(GUARD^i)) return 016;
        }
        /* Admission refusals before any pin, allocation or payload read. */
        for(f=0U;f<12U;++f) {
                diag_case_v1980=0100U+f; fault=0U;
                if(!setup14()) return 017;
                switch(f) {
                case 0U: proc_current_slot=SLOT; break;
                case 1U: PROC_CLEAR_TRANSITION(&slots[SLOT]); break;
                case 2U: mm_extents[0].meta^=3UL; break;
                case 3U: mm_extents[1].meta+=1UL<<MM_PIN_SHIFT; break;
                case 4U: ++mm_extents[1].span; break;
                case 5U: mm_extents[2].meta^=3UL; break;
                case 6U: mm_extent_capacity=2U; break;
                case 7U: u[PROC_CRED_OFFSET]&=~PROC_SWAP_MUTABLE_V1976; break;
                case 8U: roots[0]=0UL; break;
                case 9U: u[PROC_FINALIZE_OFFSET]=GUARD; break;
                case 10U: u[PROC_FDCTL_OFFSET]=PROC_USER_MAP_BIT; break;
                case 11U: u[PROC_SWAP_BACKING_OFFSET]^=1UL; break;
                }
                if(restore14()==MM_OK || restore_pins || loads || alloc_calls || finish_calls || !packed_ok() || bad_call) return 020;
        }
        mach_pi_restore(pi);
        return 0;
}
