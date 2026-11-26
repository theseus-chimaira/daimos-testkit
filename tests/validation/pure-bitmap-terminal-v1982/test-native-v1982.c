/* Appended to the real DROP/FULL fixture. Test the actual common
 * detach and original PREVM marker preservation, not a VM gate change. */
#define TFLAGS (PROC_PURE_TERM_TAG_V1920|PROC_PURE_KIND_MASK_V1919)
#define TMARK (TFLAGS|PROC_PURE_TERM_ESCROW_V1920(BASE))
#define TSPAN ((PACKED_WORDS<<18U)|BASE)
#define HEAP ((0100UL<<18U)|0600UL)
#define LIFE (PROC_FINALIZE_MARK|PROC_FINALIZE_PREVM|PROC_FINISH_RETRY_ARMED_V1763)
kword_t diag_case_v1982, diag_cases_v1982, diag_rc_v1982;
kword_t proc_timer_clock, proc_finish_last_tick_v881;
static unsigned int term_fault, term_calls;
extern void prevm_v1982(struct proc *, unsigned int);
extern int proc_swap_detach(int);
extern int proc_pure_term_v1982(int,struct proc *,kword_t);
extern int vm_space_destroy(struct proc *,unsigned int);

int term_free_v1982(kword_t base,unsigned int kind,unsigned int owner)
{
        int rc;
        ++term_calls;
        if(base!=BASE || kind!=MM_TYPE_PACKED_PROCESS || owner!=SLOT ||
            (pi_state_v1978()&0200UL) || u[PROC_BRK_OFFSET]!=TSPAN ||
            (u[PROC_FINALIZE_OFFSET]&TMARK)!=TMARK) bad_call=030U;
        if(term_fault==1U) return MM_ERR_BUSY;
        if(term_fault==2U) return MM_OK;
        if(term_fault==3U) { mm_extents[1].meta^=3UL; return MM_ERR_BUSY; }
        rc=mm_free(base,kind,owner);
        if(term_fault==4U && rc==MM_OK) {
                /* Reinsert a foreign claim INSIDE the retired interval. */
                mm_extents[2]=mm_extents[1];
                extent(1,BASE+1UL,1UL,MM_TYPE_KERNEL_DYNAMIC,0700U);
                ++mm_extent_count;
        }
        if(term_fault==5U) mm_extent_capacity=1U;
        return term_fault ? MM_ERR_BUSY:rc;
}
static int setup16(void)
{
        fault=0U;
        if(!setup14()) return 0;
        u[PROC_BRK_OFFSET]=HEAP;
        term_fault=term_calls=0U;
        proc_finish_last_tick_v881=0UL;
        proc_timer_clock=0100UL;
        return 1;
}
static int detach16(void)
{
        int rc;
        ++diag_cases_v1982;
        mach_pi_restore(0200UL);
#ifdef TEST_VM_TERM_V1982
        rc=vm_space_destroy(&slots[SLOT],SLOT);
#else
        rc=proc_swap_detach(SLOT);
#endif
        diag_rc_v1982=(kword_t)rc;
        if(!(pi_state_v1978()&0200UL)) bad_call=031U;
        (void)mach_pi_disable();
        return rc;
}
static int retired16(kword_t mark)
{
        return !records[SLOT].state && !u[PROC_SWAP_BACKING_OFFSET] &&
            u[PROC_CRED_OFFSET]==(IDENTITY&~PROC_SWAP_EXEC_MASK_V1976) &&
            u[PROC_FINALIZE_OFFSET]==mark && !u[PROC_BRK_OFFSET] &&
            PROC_TRANSITION(&slots[SLOT]) &&
#ifdef TEST_VM_TERM_V1982
            slots[SLOT].vm_state==(kword_t)-1L &&
#else
            !VM_PDP6_BASE(&slots[SLOT]) &&
#endif
            modes[0]==(1UL<<6U) && mm_extent_count==2 &&
            MM_EXTENT_BASE(&mm_extents[0])==UAREA &&
            MM_EXTENT_BASE(&mm_extents[1])==BASE+WORDS && !bad_call;
}
static int held16(kword_t mark)
{
        return records[SLOT].state==BACKING && u[PROC_SWAP_BACKING_OFFSET]==BACKING &&
            u[PROC_CRED_OFFSET]==IDENTITY && u[PROC_FINALIZE_OFFSET]==mark &&
            u[PROC_BRK_OFFSET]==TSPAN && PROC_TRANSITION(&slots[SLOT]) &&
            !VM_PDP6_BASE(&slots[SLOT]) && modes[0]==((1UL<<6U)|(3UL<<(2U*SLOT))) && !bad_call;
}
int main(void)
{
        unsigned int f;
        kword_t saved=mach_pi_disable(), b, mark, span, meta;
        int rc;
        /* Healthy, backing unavailable, lost free reply, already PREVM,
         * noncurrent foreign finalizer, fatal close, corrupt payload. */
        for(f=0U;f<7U;++f) {
                diag_case_v1982=f;
                if(!setup16()) return 1;
                mark=0UL;
                if(f==1U) roots[0]=0UL;
                if(f==2U) term_fault=6U;
                if(f==3U) u[PROC_FINALIZE_OFFSET]=mark=LIFE|0777UL;
                if(f==4U) proc_current_slot=2UL;
                if(f==5U) u[PROC_FDCTL_OFFSET]=PROC_FATAL_CLOSE_BIT;
                if(f==6U) image[22]=0UL;
                if(detach16() || !retired16(mark) || term_calls!=1U || loads || decode_calls) return 2;
                if(detach16() || !retired16(mark) || term_calls!=1U) return 3;
                fill_arenas();
                if(mm_alloc_aligned_noreclaim(PACKED_WORDS,02000UL,MM_TYPE_KERNEL_DYNAMIC,0700U,MM_ALLOC_LOW,&b)!=MM_OK || b!=BASE) return 4;
        }
        /* Default refuses mode3; staged gate also refuses a nonzero
         * APR on a nonresident mode before terminal dispatch. */
        diag_case_v1982=010U;
        if(!setup16()) return 5;
#ifdef TEST_VM_TERM_V1982
        VM_PDP6_SET_BASE(&slots[SLOT],BASE);
#endif
        if(vm_space_destroy(&slots[SLOT],SLOT)==MM_OK || term_calls || u[PROC_BRK_OFFSET]!=HEAP || !packed_ok()) return 6;
        /* Preserve the original span and status across actual PREVM
         * rearm. Refused/false success, all pin counts, wrong replacement,
         * foreign overlap, bad table, then exact original/absence. */
        for(f=0U;f<8U;++f) {
                diag_case_v1982=020U+f;
                if(!setup16()) return 7;
                if(f<5U) term_fault=f+1U;
                else mm_extents[1].meta|=(kword_t)(f-4U)<<MM_PIN_SHIFT;
                span=mm_extents[1].span; meta=mm_extents[1].meta;
                if(detach16()==MM_OK || !held16(TMARK) || term_calls!=(f<5U?1U:0U)) return 010;
                if(f>=5U && (mm_extents[1].span!=span || mm_extents[1].meta!=meta)) return 011;
                prevm_v1982(&slots[SLOT],012345U);
                mark=LIFE|012345UL;
                if(!held16(TMARK|mark)) return 012;
                term_fault=0U;
                if(f==4U) mm_extent_capacity=MM_MAX_EXTENTS;
                if(f==2U || f==3U) {
                        if(detach16()==MM_OK || !held16(TMARK|mark) || term_calls!=1U) return 013;
                        /* Lawful deletion of the injected foreign owner. */
                        mm_extents[1]=mm_extents[2]; mm_extent_count=2;
                } else if(f!=4U) {
                        mm_extents[1].meta=meta&~((kword_t)0377UL<<MM_PIN_SHIFT);
                        /* Same base but different valid length is not
                         * the original owner. Neither is another base. */
                        mm_extents[1].span=span+(1UL<<18U);
                        if(detach16()==MM_OK || !held16(TMARK|mark) || term_calls!=(f<5U?1U:0U)) return 014;
                        mm_extents[1].span=(PACKED_WORDS<<18U)|060000UL;
                        mm_extents[2].span=(0200UL<<18U)|070000UL;
                        if(detach16()==MM_OK || !held16(TMARK|mark) || term_calls!=(f<5U?1U:0U)) return 015;
                        mm_extents[1].span=span; mm_extents[2].span=(0200UL<<18U)|(BASE+WORDS);
                }
                if(detach16() || !retired16(mark) || term_calls!=(f==0U||f==1U?2U:1U)) return 016;
        }
        /* Admission must not consume BRK or a dirty transaction. */
        for(f=0U;f<19U;++f) {
                diag_case_v1982=040U+f;
                if(!setup16()) return 017;
                switch(f) {
                case 0U: proc_current_slot=SLOT; break;
                case 1U: PROC_CLEAR_TRANSITION(&slots[SLOT]); break;
                case 2U: mm_extents[0].meta^=3UL; break;
                case 3U: mm_extents[2].meta^=3UL; break;
                case 4U: ++mm_extents[1].span; break;
                case 5U: mm_extent_capacity=2U; break;
                case 6U: u[PROC_CRED_OFFSET]&=~PROC_SWAP_MUTABLE_V1976; break;
                case 7U: u[PROC_FINALIZE_OFFSET]=PROC_PURE_BITMAP_FULL_V1980(BASE,0UL); break;
                case 8U: u[PROC_FINALIZE_OFFSET]=PROC_PURE_BITMAP_FULL_V1980(BASE,060000UL)|LIFE; break;
                case 9U: u[PROC_FDCTL_OFFSET]=PROC_USER_MAP_BIT; break;
                case 10U: u[PROC_SWAP_BACKING_OFFSET]^=1UL; break;
                case 11U: u[PROC_FINALIZE_OFFSET]=PROC_SWAP_RETRY_TAG_V1507|01234UL; break;
                case 12U: u[PROC_FINALIZE_OFFSET]=PROC_FINALIZE_MARK; break;
                case 13U: u[PROC_FINALIZE_OFFSET]=LIFE|(1UL<<34U); break;
                case 14U: u[PROC_FILE_TABLE_OFFSET]=1UL; break;
                case 15U: mm_extents[1]=mm_extents[2]; --mm_extent_count; break;
                case 16U: u[PROC_FINALIZE_OFFSET]=TMARK|LIFE; break;
                case 17U: u[PROC_FINALIZE_OFFSET]=PROC_PURE_TERM_ESCROW_V1920(BASE); break;
                case 18U: u[PROC_FINALIZE_OFFSET]=LIFE|TMARK; u[PROC_BRK_OFFSET]=(PACKED_WORDS<<18U)|060000UL; break;
                }
                b=u[PROC_BRK_OFFSET]; mark=u[PROC_FINALIZE_OFFSET];
                rc=detach16();
                if(!rc || term_calls || u[PROC_BRK_OFFSET]!=b || u[PROC_FINALIZE_OFFSET]!=mark || !packed_ok() || bad_call || records[SLOT].state!=BACKING) return 020;
        }
        /* Invalid nonresident modes never retire a directory owner. */
        for(f=0U;f<3U;++f) {
                diag_case_v1982=070U+f;
                if(!setup16()) return 023;
                if(f==0U) modes[0]=(1UL<<6U)|(1UL<<(SLOT*2U));
                if(f==1U) proc_storage_runtime_v29.words=0;
                if(f==2U) modes[0]=(1UL<<6U)|(2UL<<(SLOT*2U));
                if(detach16()==MM_OK || term_calls || u[PROC_BRK_OFFSET]!=HEAP ||
                    records[SLOT].state!=BACKING || !packed_ok() || bad_call) return 024;
        }
        /* Actual legacy RAW path through same export, no BRK reuse. */
        diag_case_v1982=0100U;
        reset13(0U);
        if(proc_pure_ram_drop_v1381(SLOT)!=MM_OK) return 021;
        PROC_SET_TRANSITION(&slots[SLOT]);
        u[PROC_BRK_OFFSET]=HEAP;
        term_calls=0U;
        if(detach16() || records[SLOT].state || u[PROC_SWAP_BACKING_OFFSET] ||
            u[PROC_BRK_OFFSET]!=HEAP || term_calls || modes[0]!=(1UL<<6U) || mm_extent_count!=2) return 022;
        mach_pi_restore(saved);
        return 0;
}
