/* Appended to the unchanged v1978 native MM/provider fixture. */
#include "mm_pure_bitmap_commit_v1979.h"
#define PACKED_WORDS 176UL
#define MODE3 3U
kword_t diag_case_v1979, diag_cases_v1979;
static unsigned int commit_fault, commit_calls, arm_calls;
extern int proc_pure_mres_reclaim_v1612(kword_t,kword_t,unsigned int);
int proc_pure_recover_arm_v1902(kword_t area)
{
        (void)area; ++arm_calls; return -1;
}
int commit_mm_v1979(kword_t base,unsigned int slot,kword_t words,kword_t lengths)
{
        int rc;
        ++commit_calls;
        if(base!=BASE || slot!=SLOT || words!=WORDS ||
            lengths!=((PREFIX<<18U)|PACKED_WORDS) ||
            (pi_state_v1978() & 0200UL) ||
            !PROC_TRANSITION(&slots[SLOT]) || modes[0]!=(1UL<<6U)) bad_call=7U;
        if(commit_fault==1U) return MM_ERR_BUSY;
        if(commit_fault==3U) return MM_OK; /* false success, no commit */
        rc=mm_pure_bitmap_commit_v1979(base,slot,words,lengths);
        if(commit_fault==4U) mm_extents[1].meta^=3UL;
        if(commit_fault==5U) mm_extents[1].meta|=1UL<<MM_PIN_SHIFT;
        return commit_fault==2U || commit_fault==4U || commit_fault==5U ? MM_ERR_BUSY:rc;
}
static void reset13(unsigned int density)
{
        reset(density);
        modes[0]=1UL<<6U; /* unrelated storage-map slot */
        commit_fault=commit_calls=arm_calls=0U;
}
static int bitmap_ok(void)
{
        kword_t i;
        if(!raw_ok() || PROC_TRANSITION(&slots[SLOT]) || VM_PDP6_BASE(&slots[SLOT]) ||
            VM_SPACE_WORDS(&slots[SLOT])!=WORDS || records[SLOT].state!=BACKING ||
            u[PROC_SWAP_BACKING_OFFSET]!=BACKING || u[PROC_FINALIZE_OFFSET] ||
            u[PROC_CRED_OFFSET]!=IDENTITY || modes[0]!=((1UL<<6U)|(3UL<<(2U*SLOT))) ||
            mm_extent_count!=3 || mm_extents[1].span!=((PACKED_WORDS<<18U)|BASE) ||
            mm_extents[1].meta!=((4UL<<18U)|SLOT) ||
            mm_extents[0].span!=((PROC_UAREA_WORDS<<18U)|UAREA) ||
            mm_extents[0].meta!=((3UL<<18U)|01001UL) ||
            mm_extents[2].span!=((0200UL<<18U)|(BASE+WORDS)) ||
            mm_extents[2].meta!=((1UL<<18U)|2UL) ||
            pbmd_verify_v1979(SUFFIX,RAW,BASE,PACKED_WORDS)!=MM_OK) return 0;
        for(i=0UL;i<PROC_UAREA_WORDS;++i)
                if(i!=PROC_CRED_OFFSET && i!=PROC_SWAP_BACKING_OFFSET && u[i]) return 0;
        return 1;
}
static int raw13(void)
{
        return raw_committed() && modes[0]==((1UL<<6U)|(2UL<<(2U*SLOT)));
}
static int commit13(void)
{
        ++diag_cases_v1979;
        return proc_pure_bitmap_commit_v1979(SLOT,&lease);
}
static void fill_arenas(void)
{
        /* Exactly full original arenas: pressure must reclaim a victim. */
        mm_arena_count=2;
        mm_arenas[0]=(PROC_UAREA_WORDS<<18U)|UAREA;
        mm_arenas[1]=((WORDS+0200UL)<<18U)|BASE;
}
int main(void)
{
        unsigned int f,i;
        kword_t pi=mach_pi_disable(), oldtag, old, target, span, meta;
        int rc;
        /* Healthy and lost successful commit replies, no separate unpin. */
        for(f=0U;f<2U;++f) {
                diag_case_v1979=1U+f; reset13(0U);
                if(prepare(SLOT)!=MM_OK || !candidate_ok()) return 1;
                if(f) commit_fault=2U;
                if(commit13()!=MM_OK || !bitmap_ok() || commit_calls!=1U || rebase_calls || unpin_calls || bad_call) return 2;
                if(commit13()!=MM_ERR_BUSY || !bitmap_ok() || commit_calls!=1U) return 3;
                fill_arenas();
                /* Reuse all released words, including original RAW. */
                if(mm_alloc_aligned_noreclaim(WORDS-PACKED_WORDS,1UL,MM_TYPE_KERNEL_DYNAMIC,0700U,MM_ALLOC_LOW,&target)!=MM_OK ||
                    target!=BASE+PACKED_WORDS) return 4;
                for(i=PACKED_WORDS;i<WORDS;++i) image[i]=GUARD;
                /* Reverse expand into separately controlled disjoint area. */
                if(pbmd_decode_v1977(BASE,PACKED_WORDS,060000UL,RAW,1U)!=MM_OK) return 5;
                for(i=0U;i<RAW;++i) if(((kword_t *)060000UL)[i]!=raw_value(i)) return 6;
        }
        /* Candidate corruption: shape-valid wrong literal, zero literal,
         * wrong presence, padding, too few/extra literals. RAW survives. */
        for(f=0U;f<7U;++f) {
                diag_case_v1979=010U+f; reset13(0U);
                if(prepare(SLOT)!=MM_OK) return 7;
                switch(f) {
                case 0U: image[22]^=1UL; break;
                case 1U: image[22]=0UL; break;
                case 2U: image[0]^=0400000000000UL; break;
                case 3U: image[21]|=1UL; break;
                case 4U: --u[PROC_FINALIZE_OFFSET]; break;
                case 5U: ++u[PROC_FINALIZE_OFFSET]; image[176]=1UL; break;
                case 6U: image[0]^=0600000000000UL; break; /* same popcount */
                }
                oldtag=u[PROC_FINALIZE_OFFSET]; old=image[0];
                if(pbmd_verify_v1979(SUFFIX,RAW,BASE,oldtag&MM_HALF_MASK)==MM_OK || image[0]!=old || !raw_ok()) return 010;
                if(commit13()!=PBMP_RAW_V1979 || !raw13() || commit_calls || rebase_calls!=1U || bad_call) return 011;
        }
        /* A refused MM commit may cancel; false success or changed
         * witness must quarantine and never consume another pin. */
        for(f=1U;f<=5U;++f) {
                diag_case_v1979=020U+f; reset13(0U);
                if(prepare(SLOT)!=MM_OK) return 012;
                commit_fault=f; oldtag=u[PROC_FINALIZE_OFFSET]; rc=commit13();
                if(f==1U) { if(rc!=PBMP_RAW_V1979 || !raw13()) return 013; }
                else if(f==2U) { if(rc!=MM_OK || !bitmap_ok()) return 014; }
                else if(rc!=MM_ERR_BUSY || !PROC_TRANSITION(&slots[SLOT]) ||
                    VM_PDP6_BASE(&slots[SLOT])!=BASE || u[PROC_FINALIZE_OFFSET]!=oldtag ||
                    modes[0]!=(1UL<<6U) || rebase_calls || unpin_calls || !raw_ok()) return 015;
                if(commit_calls!=1U || bad_call) return 016;
        }
        /* Commit refused and RAW cancellation itself fails: do not
         * resume dirty text or misreport success after mode2 publish. */
        for(f=0U;f<3U;++f) {
                diag_case_v1979=030U+f; reset13(0U);
                if(prepare(SLOT)!=MM_OK) return 033;
                oldtag=u[PROC_FINALIZE_OFFSET]; commit_fault=1U;
                if(f==0U) rebase_fault=1U;
                if(f==1U) unpin_fault=1U;
                if(f==2U) { rebase_fault=2U; unpin_fault=2U; }
                rc=commit13();
                if(f==2U) { if(rc!=PBMP_RAW_V1979 || !raw13()) return 034; }
                else {
                        if(rc!=MM_ERR_BUSY || !raw_ok() || !PROC_TRANSITION(&slots[SLOT]) ||
                            u[PROC_FINALIZE_OFFSET]!=oldtag || !MM_EXTENT_PINS(&mm_extents[1])) return 035;
                        if(f==0U && (VM_PDP6_BASE(&slots[SLOT])!=BASE || unpin_calls ||
                            legacy_gate_v1978(SLOT,PROC_STORAGE_RESIDENT))) return 036;
                        if(f==1U && (VM_PDP6_BASE(&slots[SLOT]) ||
                            proc_storage_expect_v30(SLOT,PROC_STORAGE_PACKED) ||
                            legacy_gate_v1978(SLOT,PROC_STORAGE_PACKED))) return 037;
                }
        }
        /* Independent MM primitive rejects invalid geometry and owner
         * before metadata mutation, even when called without C guard. */
        for(f=0U;f<17U;++f) {
                unsigned int slot=SLOT;
                kword_t base=BASE, words=WORDS, lengths=(PREFIX<<18U)|PACKED_WORDS;
                diag_case_v1979=040U+f; reset13(0U);
                if(prepare(SLOT)!=MM_OK) return 017;
                switch(f) {
                case 0U: base+=1UL; break;
                case 1U: slot=0U; break;
                case 2U: words+=02000UL; break;
                case 3U: lengths=PACKED_WORDS; break;
                case 4U: lengths=(PREFIX<<18U)|0UL; break;
                case 5U: lengths=(PREFIX<<18U)|(PREFIX+1UL); break;
                case 6U: lengths=(PREFIX<<18U)|1UL; break;
                case 7U: lengths=((PREFIX+1UL)<<18U)|PACKED_WORDS; break;
                case 8U: mm_extents[1].meta^=3UL; break;
                case 9U: mm_extents[1].meta+=1UL<<MM_PIN_SHIFT; break;
                case 10U: mm_extents[1].meta-=1UL<<MM_PIN_SHIFT; break;
                case 11U: mm_extents[2].meta^=3UL; break;
                case 12U: --mm_extents[2].span; break;
                case 13U: mm_extent_capacity=2U; break;
                case 14U: lengths=(WORDS<<18U)|PACKED_WORDS; break; /* no RAW */
                case 15U: lengths=(01400UL<<18U)|0400UL; break; /* equal to RAW */
                case 16U: base|=01000000UL; break;
                }
                for(i=0U;i<3U;++i) before[i]=mm_extents[i];
                ++diag_cases_v1979;
                if(mm_pure_bitmap_commit_v1979(base,slot,words,lengths)==MM_OK) return 020;
                for(i=0U;i<3U;++i) if(before[i].span!=mm_extents[i].span || before[i].meta!=mm_extents[i].meta) return 021;
                if(!raw_ok()) return 022;
        }
        /* Original token cannot authorize replacement backing or owner. */
        for(f=0U;f<5U;++f) {
                diag_case_v1979=070U+f; reset13(0U);
                if(prepare(SLOT)!=MM_OK) return 023;
                switch(f) {
                case 0U: lease.backing^=1UL; break;
                case 1U: lease.vm_state^=02000UL; break;
                case 2U: mm_extents[1].meta^=3UL; break;
                case 3U: u[PROC_FINALIZE_OFFSET]&=~MM_HALF_MASK; break;
                case 4U: modes[0]|=2UL<<(SLOT*2U); break;
                }
                span=mm_extents[1].span; meta=mm_extents[1].meta;
                if(commit13()!=MM_ERR_BUSY || commit_calls || rebase_calls || unpin_calls ||
                    span!=mm_extents[1].span || meta!=mm_extents[1].meta || !raw_ok()) return 024;
        }
        /* Real staged reclaim selection with no initial free gap.
         * v1984: an active RT lease excludes the codec, but must not
         * remove the original RAW reclaim option for a sleeping owner. */
        for(f=0U;f<8U;++f) {
                diag_case_v1979=0100U+f; reset13(f==1U?1U:f==2U?2U:0U);
                fill_arenas(); PROC_CLEAR_TRANSITION(&slots[SLOT]);
                if(f==3U) u[PROC_CRED_OFFSET]&=~PROC_SWAP_MUTABLE_V1976;
                if(f==4U) encode_fault=1U;
                if(f==5U) commit_fault=1U;
                if(f==6U) proc_rt_owner=2UL;
                if(f==7U) proc_rt_owner=SLOT;
                ++diag_cases_v1979;
                rc=proc_pure_mres_reclaim_v1612(f==0U?512UL:128UL,1UL,3U);
                if(f==0U) { if(rc!=MM_OK || !bitmap_ok() || commit_calls!=1U) return 025; }
                else if(f==4U) {
                        if(rc!=PBMD_WRITE_FAULT_V1977 || !PROC_TRANSITION(&slots[SLOT]) ||
                            !MM_EXTENT_PINS(&mm_extents[1]) || commit_calls || rebase_calls || unpin_calls || arm_calls) return 026;
                } else {
                        if(rc!=MM_OK || PROC_TRANSITION(&slots[SLOT]) || VM_PDP6_BASE(&slots[SLOT]) ||
                            proc_storage_expect_v30(SLOT,PROC_STORAGE_PACKED) || !raw_ok() || rebase_calls!=1U) return 027;
                        if(f!=3U && !raw13()) return 030;
                        if(f>=6U && (encode_calls || commit_calls || arm_calls ||
                            proc_rt_owner!=(f==6U?2UL:SLOT))) return 035;
                }
                if(bad_call) return 031;
        }
        if(pi_state_v1978() & 0200UL) return 032;
        mach_pi_restore(pi);
        return 0;
}
