/* Complete original finalizer/reaper + actual relocated bitmap owner.
 * Outer session/notification services are controlled fixtures; MM,
 * parent eligibility, stack guard, VM destroy and retry are original. */
#define PARENT_V1988 2U
#define PAREA_V1988 054000UL
#define STATUS_V1988 0400001U
#define SAVED_PC_V1988 ((010000UL<<18U)|020UL)
kword_t proc_exec_resv_head_v1933, proc_sched_kick;
kword_t diag_case_v1988, diag_cases_v1988;
static unsigned int hups, tty_calls, removed, adopted, notified;
extern int proc_finish_service_v881(void);
extern void backoff_v1988(void);
int proc_session_teardown(unsigned int slot,kword_t ctl)
{
        ++hups;
        if(slot!=SLOT || ctl) bad_call=050U;
        return 0;
}
int proc_tty_release_session(unsigned int session,unsigned int slot)
{
        ++tty_calls;
        if(session || slot!=SLOT) bad_call=051U;
        return 0;
}
void proc_runq_remove(unsigned int slot)
{
        ++removed;
        if(slot!=SLOT) bad_call=052U;
}
void proc_adopt_children_pdp6(unsigned int slot)
{
        ++adopted;
        if(slot!=SLOT) bad_call=053U;
}
void proc_notify_parent(unsigned int slot)
{
        ++notified;
        if(slot!=PARENT_V1988) bad_call=054U;
}
void proc_trim_high(void) { bad_call=055U; }
int proc_has_live_user(void) { return 1; }
int proc_slot_discard(unsigned int slot)
{
        (void)slot; bad_call=056U; return -1;
}
int proc_swap_service_one(void)
{
        bad_call=057U; return -1;
}
static int setup19(void)
{
        unsigned int i;
        reset17();
        if(drop17() || !placed17()) return 0;
        slots[SLOT].meta|=(kword_t)PARENT_V1988<<8U;
        slots[SLOT].sched=(kword_t)PROC_STOP<<PROC_STATE_SHIFT;
        u[020]=SAVED_PC_V1988;
        u[PROC_BRK_OFFSET]=HEAP;
        extent(2,BASE+WORDS,WORDS,MM_TYPE_PROCESS,PARENT_V1988);
        extent(3,PAREA_V1988,PROC_UAREA_WORDS,MM_TYPE_KERNEL_DYNAMIC,01000U+PARENT_V1988);
        mm_extent_count=4;
        for(i=0;i<PROC_UAREA_WORDS;++i) ((kword_t *)PAREA_V1988)[i]=0;
        slots[PARENT_V1988].meta=(PAREA_V1988<<18U)|((kword_t)PROC_F_UAREA<<PROC_FLAGS_SHIFT);
        VM_PDP6_SET_SPACE(&slots[PARENT_V1988],WORDS,BASE+WORDS);
        slots[PARENT_V1988].sched=(kword_t)PROC_SRUN<<PROC_STATE_SHIFT;
        slots[3].meta=slots[3].vm_state=slots[3].sched=0UL;
        modes[0]=3UL<<(2U*SLOT);
        records[PARENT_V1988].state=records[3].state=0UL;
        proc_current_slot=PARENT_V1988;
        proc_exec_resv_head_v1933=proc_sched_kick=0UL;
        proc_timer_clock=0100UL; proc_finish_last_tick_v881=0UL;
        hups=tty_calls=removed=adopted=notified=0U;
        return mm_pure_table_v1922()==MM_OK;
}
static int final19(void)
{
        return !bad_call && !records[SLOT].state && !modes[0] &&
            slots[SLOT].vm_state==(kword_t)-1L &&
            PROC_STATE(&slots[SLOT])==PROC_ZOMB &&
            !PROC_HAS_UAREA(&slots[SLOT]) && !PROC_TRANSITION(&slots[SLOT]) &&
            (slots[SLOT].meta>>18U)==STATUS_V1988 &&
            mm_extent_count==2 &&
            MM_EXTENT_BASE(&mm_extents[0])==BASE+WORDS &&
            MM_EXTENT_OWNER(&mm_extents[0])==PARENT_V1988 &&
            MM_EXTENT_BASE(&mm_extents[1])==PAREA_V1988 &&
            MM_EXTENT_OWNER(&mm_extents[1])==01000U+PARENT_V1988 &&
            !(proc_finish_last_tick_v881>>18U) &&
            hups==1U && removed==1U && adopted==1U && notified==1U;
}
static int held19(unsigned int pins,kword_t delay)
{
        return !bad_call && PROC_TRANSITION(&slots[SLOT]) &&
            PROC_STATE(&slots[SLOT])==PROC_STOP && !VM_PDP6_BASE(&slots[SLOT]) &&
            records[SLOT].state==BACKING && u[PROC_SWAP_BACKING_OFFSET]==BACKING &&
            u[PROC_CRED_OFFSET]==IDENTITY && u[020]==SAVED_PC_V1988 &&
            u[PROC_BRK_OFFSET]==TSPAN &&
            u[PROC_FINALIZE_OFFSET]==(TMARK|LIFE|STATUS_V1988) &&
            modes[0]==(3UL<<(2U*SLOT)) && mm_extent_count==4 &&
            proc_pure_owner_v1918(SLOT,MM_TYPE_PACKED_PROCESS,LOW_V1985,PACKED_WORDS,pins)==LOW_V1985 &&
            (proc_finish_last_tick_v881>>18U)==(0400000UL|delay) &&
            hups==1U && !removed && !adopted && !notified &&
            pbmd_verify_v1979(SUFFIX,RAW,LOW_V1985,PACKED_WORDS)==MM_OK;
}
int main(void)
{
        unsigned int f,i,pins;
        kword_t saved=mach_pi_disable();
        for(f=0;f<5U;++f) {
                diag_case_v1988=f+1U;
                if(!setup19()) return 1;
                pins=f<2U?f+1U:0U;
                for(i=0;i<pins;++i) if(mm_pin(LOW_V1985)) return 2;
                term_fault=f==2U?1U:f==3U?2U:f==4U?6U:0U;
                ++diag_cases_v1988;
                if(f==4U) {
                        if(proc_finish_slot(SLOT,STATUS_V1988) || !final19() || term_calls!=1U) return 3;
                        continue;
                }
                if(proc_finish_slot(SLOT,STATUS_V1988)==0 || !held19(pins,020UL)) return 4;
                proc_current_slot=0UL;
                for(i=0;i<2U;++i) {
                        backoff_v1988();
                        ++diag_cases_v1988;
                        if(proc_finish_service_v881() || !held19(pins,040UL<<i)) return 5;
                }
                for(i=0;i<pins;++i) if(mm_unpin(LOW_V1985)) return 6;
                term_fault=0U;
                backoff_v1988();
                ++diag_cases_v1988;
                if(proc_finish_service_v881() || !final19()) return 7;
        }
        /* Foreign finalizer must refuse before any HUP or VM operation
         * when the original returning stack or FILE owner is live. */
        for(f=0;f<4U;++f) {
                diag_case_v1988=010U+f;
                if(!setup19()) return 010;
                if(f==0U) proc_exec_resv_head_v1933=UAREA+PROC_USTACK_BASE;
                if(f==1U) u[020]=020UL;
                if(f==2U) slots[SLOT].sched|=(kword_t)PROC_WAIT_EVENT<<PROC_WAIT_SHIFT;
                if(f==3U) u[PROC_FILE_TABLE_OFFSET]=1UL;
                ++diag_cases_v1988;
                if(proc_finish_slot(SLOT,STATUS_V1988)==0 || hups || tty_calls ||
                    term_calls || PROC_TRANSITION(&slots[SLOT]) || u[PROC_FINALIZE_OFFSET] ||
                    u[PROC_BRK_OFFSET]!=HEAP || modes[0]!=(3UL<<(2U*SLOT)) ||
                    mm_extent_count!=4 || bad_call) return 011;
        }
        mach_pi_restore(saved);
        return 0;
}
