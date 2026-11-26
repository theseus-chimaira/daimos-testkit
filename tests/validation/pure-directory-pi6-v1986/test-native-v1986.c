/* Actual mode3 service -> original native run-queue selector.
 * Provider fault replies remain controlled; no claim of hardware PI6. */
kword_t proc_sched_deferred_ticks, proc_sched_age_phase;
kword_t proc_finish_last_tick_v881, proc_timer_clock, proc_runq_head;
kword_t kconst_7_7=07000007UL;
kword_t diag_case_v1986, diag_cases_v1986;

#define PEER 2U
#define PEER_BASE (BASE+WORDS)
#define PEER_AREA (PEER_BASE+WORDS)
#define READY_V1986 01000UL

static void priorities(unsigned int first,unsigned int second)
{
        slots[SLOT].sched=((kword_t)PROC_SRUN<<PROC_STATE_SHIFT)|
            ((kword_t)first<<PROC_NICE_SHIFT)|PEER;
        slots[PEER].sched=((kword_t)PROC_SRUN<<PROC_STATE_SHIFT)|
            ((kword_t)second<<PROC_NICE_SHIFT);
}

static int setup18(void)
{
        unsigned int i;
        if(!setup15()) return 0;
        /* Actual exact resident peer and independent stable u-area. */
        extent(2,PEER_BASE,WORDS,MM_TYPE_PROCESS,PEER);
        extent(3,PEER_AREA,PROC_UAREA_WORDS,MM_TYPE_KERNEL_DYNAMIC,01000U+PEER);
        mm_extent_count=4;
        for(i=0U;i<PROC_UAREA_WORDS;++i) ((kword_t *)PEER_AREA)[i]=0UL;
        slots[PEER].meta=(PEER_AREA<<18U)|((kword_t)PROC_F_UAREA<<PROC_FLAGS_SHIFT);
        VM_PDP6_SET_SPACE(&slots[PEER],WORDS,PEER_BASE);
        records[PEER].state=0UL;
        priorities(1U,030U);
        proc_runq_head=SLOT;
        proc_sched_cursor=PEER;
        proc_sched_deferred_ticks=proc_sched_age_phase=0UL;
        proc_finish_last_tick_v881=0UL;
        proc_timer_clock=0100UL;
        return mm_pure_table_v1922()==MM_OK;
}

static int choose(unsigned int clock,kword_t selected,kword_t cursor)
{
        kword_t rc;
        ++diag_cases_v1986;
        rc=clock?proc_sched_tick_select():proc_sched_resched_select();
        return rc==selected && proc_sched_cursor==cursor &&
            proc_current_slot==0UL && proc_rt_owner==0UL &&
            mm_pure_table_v1922()==MM_OK;
}

static int once18(unsigned int clock)
{
        /* A strictly better peer cannot steal the first restored turn. */
        priorities(030U,1U);
        if(!choose(clock,SLOT,SLOT)) return 0;
        /* But the hint cannot override priority a second time. */
        return choose(clock,PEER,PEER);
}

int main(void)
{
        unsigned int f,clock;
        kword_t saved=mach_pi_disable(),tag;
        install_d6_v1980();
        for(clock=0U;clock<2U;++clock) {
                for(f=0U;f<3U;++f) {
                        diag_case_v1986=1U+f+010U*clock;
                        fault=f==1U?1U:0U;
                        if(!setup18() || !choose(clock,0UL,PROC_SCHED_SWAP_REQUEST|SLOT)) return 1;
                        lost15=f==2U;
                        if(service15(0UL)!=(int)(READY_V1986|SLOT) || !ready15()) return 2;
                        if(!once18(clock)) return 3;
                }
                /* Short read preserves exact clean compressed owner.
                 * A higher-ranked nonresident may not suppress a peer
                 * during global pressure cooldown. Retry after expiry. */
                diag_case_v1986=020U+clock;
                fault=2U;
                if(!setup18() || !choose(clock,0UL,PROC_SCHED_SWAP_REQUEST|SLOT)) return 4;
                if(service15(0UL) || PROC_TRANSITION(&slots[SLOT]) || !packed_ok() ||
                    u[PROC_FINALIZE_OFFSET] || proc_swap_pressure_ticks!=0100UL ||
                    modes[0]!=((1UL<<6U)|(3UL<<(2U*SLOT))) || bad_call) return 5;
                if(!choose(clock,PEER,PEER)) return 6;
                /* Deliberately stale READY_ONCE on a clean nonresident. */
                proc_sched_cursor=READY_V1986|SLOT;
                if(!choose(clock,PEER,PEER)) return 7;
                proc_swap_pressure_ticks=0UL; fault=0U; calls15=finish_calls=0U;
                if(!choose(clock,0UL,PROC_SCHED_SWAP_REQUEST|SLOT) ||
                    service15(0UL)!=(int)(READY_V1986|SLOT) || !ready15() ||
                    !once18(clock)) return 010;
                /* False success cannot publish READY. Dirty source and
                 * target stay pinned/transition-held; the original selector
                 * must never ask for them even after cooldown expires. */
                diag_case_v1986=030U+clock;
                fault=15U;
                if(!setup18() || !choose(clock,0UL,PROC_SCHED_SWAP_REQUEST|SLOT)) return 011;
                if(service15(0UL) || !PROC_TRANSITION(&slots[SLOT]) ||
                    !(tag=u[PROC_FINALIZE_OFFSET]) || VM_PDP6_BASE(&slots[SLOT]) ||
                    proc_sched_cursor!=SLOT || bad_call || arm_calls) return 012;
                proc_swap_pressure_ticks=0UL;
                if(!choose(clock,PEER,PEER)) return 013;
                proc_sched_cursor=READY_V1986|SLOT;
                if(!choose(clock,PEER,PEER) || u[PROC_FINALIZE_OFFSET]!=tag ||
                    !PROC_TRANSITION(&slots[SLOT])) return 014;
                /* READY stale after publication but before dispatch:
                 * state/transition checks must still reject it. */
                for(f=0U;f<2U;++f) {
                        diag_case_v1986=040U+2U*clock+f;
                        fault=0U;
                        if(!setup18() || !choose(clock,0UL,PROC_SCHED_SWAP_REQUEST|SLOT) ||
                            service15(0UL)!=(int)(READY_V1986|SLOT) || !ready15()) return 015;
                        priorities(030U,1U);
                        if(f) PROC_SET_TRANSITION(&slots[SLOT]);
                        else slots[SLOT].sched=((kword_t)PROC_STOP<<PROC_STATE_SHIFT);
                        /* Actual runq removal accompanies STOP. */
                        if(!f) proc_runq_head=PEER;
                        if(!choose(clock,PEER,PEER)) return 016;
                }
        }
        mach_pi_restore(saved);
        return 0;
}
