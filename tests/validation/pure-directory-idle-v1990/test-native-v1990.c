/* Actual service + original idle deadline, armer, scan and backoff.
 * Outer interrupt handoff is not simulated. Terminal fixture calls
 * are counted to detect misclassification, not used as MM authority. */
kword_t proc_sched_cursor, proc_swap_pressure_ticks, proc_sched_kick;
kword_t diag_case_v1990, diag_cases_v1990;
static unsigned int terms20, discards20, services20;
extern int idle_due_v1990(void);
extern int proc_pure_mres_service_v1612(kword_t);
int load20(kword_t backing,kword_t target,kword_t area,kword_t words)
{
        return load19(backing,target,area,words);
}
int service_gate_v1990(kword_t command)
{
        ++services20;
        return proc_pure_mres_service_v1612(command);
}
int proc_finish_slot(unsigned int slot,unsigned int status)
{
        (void)slot; (void)status;
        ++terms20;
        return -1;
}
int proc_slot_discard(unsigned int slot)
{
        (void)slot;
        ++discards20;
        return -1;
}
int proc_has_live_user(void) { return 1; }

static int setup20(unsigned int grown)
{
        if(!setup19(grown)) return 0;
        slots[2].meta=slots[2].vm_state=slots[2].sched=0UL;
        slots[3].meta=slots[3].vm_state=slots[3].sched=0UL;
        records[2].state=records[3].state=0UL;
        PROC_CLEAR_TRANSITION(&slots[SLOT]);
        proc_sched_cursor=PROC_SCHED_SWAP_REQUEST|SLOT;
        proc_swap_pressure_ticks=proc_sched_kick=0UL;
        proc_timer_clock=0100UL; proc_finish_last_tick_v881=0UL;
        terms20=discards20=services20=0U;
        return 1;
}
static int service20(kword_t cmd)
{
        int rc;
        ++diag_cases_v1990;
        mach_pi_restore(0200UL);
        rc=proc_pure_mres_service_v1612(cmd);
        if(!(pi_state_v1978()&0200UL)) bad_call=061U;
        (void)mach_pi_disable();
        return rc;
}
static int due20(kword_t tick)
{
        ++diag_cases_v1990;
        proc_timer_clock=tick;
        return idle_due_v1990();
}
static int clock20(kword_t epoch,kword_t delay)
{
        return proc_finish_last_tick_v881==
            (((0400000UL|delay)<<18U)|(epoch&0377777UL));
}
/* An independent exact original RAW owner shares the retry scan.
 * No adopted source geometry, pin, or backing I/O is needed. */
#define PEER_AREA_V1990 054000UL
#define PEER_RAW_V1990 (BASE+WORDS+PREFIX)
static int peer20(void)
{
        kword_t i, *area=(kword_t *)PEER_AREA_V1990;
        if(mm_extent_count!=4U) return 0;
        mm_extents[4]=mm_extents[3];
        extent(2,PEER_RAW_V1990,RAW,MM_TYPE_PACKED_PROCESS,2U);
        extent(3,PEER_AREA_V1990,PROC_UAREA_WORDS,MM_TYPE_KERNEL_DYNAMIC,01002U);
        mm_extent_count=5U;
        for(i=0UL;i<PROC_UAREA_WORDS;++i) area[i]=0UL;
        slots[2].meta=(PEER_AREA_V1990<<18U)|
            ((kword_t)(PROC_F_UAREA|PROC_F_TRANSITION)<<PROC_FLAGS_SHIFT);
        VM_PDP6_SET_SPACE(&slots[2],WORDS,0UL);
        slots[2].sched=(kword_t)PROC_SRUN<<PROC_STATE_SHIFT;
        records[2].state=area[PROC_SWAP_BACKING_OFFSET]=BACKING;
        area[PROC_CRED_OFFSET]=IDENTITY&~PROC_SWAP_MUTABLE_V1976;
        area[PROC_FINALIZE_OFFSET]=PROC_PURE_FULL_ESCROW_V1917(PEER_RAW_V1990,0UL);
        modes[0]|=2UL<<4U;
        return mm_pure_table_v1922()==MM_OK;
}
int main(void)
{
        unsigned int f,g,i,phase,ops;
        kword_t saved=mach_pi_disable(), epoch,delay,tag,brk,span;
        install_d6_v1980();
        /* All standalone v1989 cases with the new retry-bit spelling. */
        if(old_main_v1989()) return 1;
        for(g=0U;g<2U;++g) {
                for(f=1U;f<=3U;++f) {
                        diag_case_v1990=(g<<6U)|f;
                        if(!setup20(g)) return 2;
                        /* Include 17-bit clock wrap in the grown VM. */
                        epoch=g?0377770UL:0100UL;
                        proc_timer_clock=epoch; f19=f; phase=f+1U;
                        if(service20(0UL) || !clock20(epoch,020UL) ||
                            !held19(phase,phase==4U?0UL:target_addr) ||
                            proc_sched_cursor!=SLOT || proc_swap_pressure_ticks!=0100UL) return 3;
                        tag=u[PROC_FINALIZE_OFFSET]; brk=u[PROC_BRK_OFFSET];
                        delay=020UL;
                        for(i=0U;i<7U;++i) {
                                ops=services20;
                                if(due20((epoch+delay-1UL)&0377777UL) ||
                                    services20!=ops || !clock20(epoch,delay)) return 4;
                                epoch=(epoch+delay)&0377777UL;
                                if(!due20(epoch) || services20!=ops+1U ||
                                    u[PROC_FINALIZE_OFFSET]!=tag ||
                                    u[PROC_BRK_OFFSET]!=brk || !held19(phase,phase==4U?0UL:target_addr)) return 5;
                                if(delay<01000UL) delay*=2UL;
                                if(!clock20(epoch,delay) || proc_sched_cursor!=SLOT ||
                                    terms20 || discards20 || bad_call) return 6;
                        }
                        /* Recovery does not load or publish READY; preserve
                         * a different pending scheduler request. */
                        roots[0]=0UL; f19=0U;
                        proc_sched_cursor=PROC_SCHED_SWAP_REQUEST|2U;
                        if(!due20((epoch+delay)&0377777UL) || !clean19(0U) ||
                            proc_finish_last_tick_v881>>18U || terms20 || discards20 ||
                            proc_sched_cursor!=(PROC_SCHED_SWAP_REQUEST|2U) ||
                            loads19!=1U || finishes19 || pins19!=2U || allocs19!=1U) return 7;
                        ops=services20;
                        if(due20((epoch+delay+01000UL)&0377777UL) || services20!=ops) return 010;
                        roots[0]=VFS_NODE(MEMFS_PROVIDER,VFS_MOUNT_KIND(1U,1U),1U);
                        proc_sched_cursor=PROC_SCHED_SWAP_REQUEST|SLOT;
                        proc_swap_pressure_ticks=0UL;
                        if(service20(0UL)!=(int)(01000UL|SLOT) || !resident19() ||
                            proc_sched_cursor!=(01000UL|SLOT)) return 011;
                }
        }
        /* HOLD cannot arm or participate in an unrelated retry scan. */
        for(f=0U;f<3U;++f) {
                diag_case_v1990=0200U+f;
                if(!setup20(1U)) return 012;
                f19=f==0U?F19_FINISH_FALSE:f==1U?F19_SOURCE_FALSE:F19_CODEC_HARD;
                if(service20(0UL) || proc_finish_last_tick_v881 ||
                    !PROC_TRANSITION(&slots[SLOT]) || (u[PROC_FINALIZE_OFFSET]&(1UL<<32U))) return 013;
                tag=u[PROC_FINALIZE_OFFSET]; brk=u[PROC_BRK_OFFSET];
                proc_finish_last_tick_v881=(0400020UL<<18U)|0100UL;
                if(!due20(0120UL) || services20 || terms20 || discards20 ||
                    proc_finish_last_tick_v881>>18U ||
                    u[PROC_FINALIZE_OFFSET]!=tag || u[PROC_BRK_OFFSET]!=brk) return 014;
                /* Direct stale/forged tagged command cannot act on HOLD. */
                if(service20(0400000UL|SLOT)==MM_OK || !PROC_TRANSITION(&slots[SLOT]) ||
                    u[PROC_FINALIZE_OFFSET]!=tag || u[PROC_BRK_OFFSET]!=brk) return 015;
        }
        /* Changed exact MM geometry revokes phase during real scan;
         * next scan skips HOLD and clears shared pending state. */
        diag_case_v1990=0210U;
        if(!setup20(0U)) return 016;
        f19=F19_TARGET_UNPIN;
        if(service20(0UL) || !clock20(0100UL,020UL)) return 017;
        span=mm_extents[1].span; mm_extents[1].span+=1UL<<18U;
        ops=unpins19; f19=0U;
        if(!due20(0120UL) || services20!=1U || unpins19!=ops ||
            (u[PROC_FINALIZE_OFFSET]&(1UL<<32U)) || !clock20(0120UL,040UL)) return 020;
        mm_extents[1].span=span;
        if(!due20(0160UL) || services20!=1U || unpins19!=ops ||
            proc_finish_last_tick_v881>>18U || !held19(1U,target_addr)) return 021;
        /* Bad command and nonzero current slot cannot touch owner. */
        diag_case_v1990=0211U;
        if(!setup20(0U)) return 022;
        f19=F19_SOURCE_UNPIN;
        if(service20(0UL) || !clock20(0100UL,020UL)) return 023;
        tag=u[PROC_FINALIZE_OFFSET]; brk=u[PROC_BRK_OFFSET]; ops=unpins19;
        f19=0U; proc_current_slot=2UL;
        if(service20(0400000UL|SLOT)==MM_OK || service20(0400400UL|SLOT)==MM_OK ||
            u[PROC_FINALIZE_OFFSET]!=tag || u[PROC_BRK_OFFSET]!=brk ||
            unpins19!=ops || !clock20(0100UL,020UL)) return 024;
        proc_current_slot=0UL;
        if(!due20(0120UL) || !clean19(0U) || terms20 || discards20) return 025;
        /* Actual legacy RAW and directory owner in one shared scan.
         * RAW unlock cannot clear another owner's retry/backoff. */
        diag_case_v1990=0220U;
        if(!setup20(0U)) return 026;
        f19=F19_TARGET_UNPIN;
        if(service20(0UL) || !clock20(0100UL,020UL) || !peer20()) return 027;
        if(!due20(0120UL) || services20!=2U || !clock20(0120UL,040UL) ||
            !escrow19(2U,target_addr) || !payload19() || modes[0]!=(MODE3_V1985|(2UL<<4U)) ||
            !PROC_TRANSITION(&slots[SLOT]) || PROC_TRANSITION(&slots[2]) ||
            ((kword_t *)PEER_AREA_V1990)[PROC_FINALIZE_OFFSET] ||
            proc_pure_owner_v1918(2U,MM_TYPE_PACKED_PROCESS,PEER_RAW_V1990,RAW,0U)!=PEER_RAW_V1990 ||
            terms20 || discards20 || bad_call) return 030;
        f19=0U;
        if(!due20(0160UL) || services20!=3U || proc_finish_last_tick_v881>>18U ||
            PROC_TRANSITION(&slots[SLOT]) || VM_PDP6_BASE(&slots[SLOT]) ||
            u[PROC_FINALIZE_OFFSET] || u[PROC_BRK_OFFSET]!=heap19 || !payload19() ||
            modes[0]!=(MODE3_V1985|(2UL<<4U)) ||
            proc_pure_owner_v1918(2U,MM_TYPE_PACKED_PROCESS,PEER_RAW_V1990,RAW,0U)!=PEER_RAW_V1990 ||
            proc_pure_full_owners_v1917(SLOT,LOW_V1985,encoded19,0UL,words19,0U,0U)!=1 ||
            terms20 || discards20 || bad_call) return 031;
        mach_pi_restore(saved);
        return 0;
}
