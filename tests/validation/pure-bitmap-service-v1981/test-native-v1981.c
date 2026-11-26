/* Native slot-zero service, using the v1980 real DROP/FULL fixture.
 * No scheduler selection or PI6 interrupt is simulated by this driver. */
kword_t proc_sched_cursor, proc_swap_pressure_ticks;
kword_t diag_case_v1981, diag_cases_v1981, diag_rc_v1981;
static unsigned int calls15, lost15;
extern int proc_pure_mres_service_v1612(kword_t);
int service_restore_v1981(unsigned int slot,proc_pure_ram_loader_v1391 loader)
{
        int rc;
        ++calls15;
        if(loader!=load_v1980 || slot!=SLOT || !PROC_TRANSITION(&slots[SLOT])) bad_call=021U;
        rc=proc_pure_bitmap_restore_v1980(slot,loader);
        return lost15 ? MM_ERR_BUSY:rc;
}
static int service15(kword_t command)
{
        int rc;
        ++diag_cases_v1981;
        mach_pi_restore(0200UL);
        rc=proc_pure_mres_service_v1612(command);
        diag_rc_v1981=(kword_t)rc;
        if(!(pi_state_v1978()&0200UL)) bad_call=022U;
        (void)mach_pi_disable();
        return rc;
}
static int setup15(void)
{
        if(!setup14()) return 0;
        PROC_CLEAR_TRANSITION(&slots[SLOT]);
        proc_sched_cursor=PROC_SCHED_SWAP_REQUEST|SLOT;
        proc_swap_pressure_ticks=0UL;
        calls15=lost15=0U;
        return 1;
}
static int ready15(void)
{
        return proc_sched_cursor==(01000UL|SLOT) && !proc_swap_pressure_ticks &&
            !PROC_TRANSITION(&slots[SLOT]) && VM_PDP6_BASE(&slots[SLOT])==TARGET &&
            modes[0]==(1UL<<6U) && !u[PROC_FINALIZE_OFFSET] &&
            !u[PROC_SWAP_BACKING_OFFSET] && full_ok(TARGET) && calls15==1U &&
            finish_calls==1U && !arm_calls && !bad_call;
}
static int inactive15(void)
{
        return !PROC_TRANSITION(&slots[SLOT]) && !VM_PDP6_BASE(&slots[SLOT]) &&
            modes[0]==((1UL<<6U)|(3UL<<(2U*SLOT))) &&
            !u[PROC_FINALIZE_OFFSET] && packed_ok() && !MM_EXTENT_PINS(&mm_extents[1]) &&
            mm_extent_count==3 && proc_swap_pressure_ticks==0100UL &&
            proc_sched_cursor==SLOT && !arm_calls && !bad_call;
}
int main(void)
{
        unsigned int f;
        kword_t saved=mach_pi_disable(), tag;
        int rc;
        install_d6_v1980();
        /* Healthy plain/compressed and lost success from restore. */
        for(f=0U;f<3U;++f) {
                diag_case_v1981=f; fault=f==1U?1U:0U;
                if(!setup15()) return 1;
                lost15=(f==2U);
                if(service15(0UL)!=(int)(01000UL|SLOT) || !ready15()) return 2;
                /* READY_ONCE is not another restore request. */
                if(service15(0UL) || calls15!=1U || !ready15()) return 3;
        }
        /* Retry with original source after ordinary short read, no-fit,
         * source pin refusal, MM commit refusal, missing backing. */
        for(f=0U;f<5U;++f) {
                diag_case_v1981=010U+f;
                fault=f==0U?2U:f==1U?8U:f==2U?10U:f==3U?13U:0U;
                if(!setup15()) return 4;
                if(f==1U) fill_arenas();
                if(f==4U) roots[0]=0UL;
                if(service15(0UL) || !inactive15() || calls15!=1U) return 5;
                /* Backing/space recovers. No change to source or slot. */
                fault=0U; mm_arena_count=1; mm_arenas[0]=(040000UL<<18U)|040000UL;
                roots[0]=VFS_NODE(MEMFS_PROVIDER,VFS_MOUNT_KIND(1U,1U),1U);
                calls15=finish_calls=0U; proc_swap_pressure_ticks=0UL;
                proc_sched_cursor=PROC_SCHED_SWAP_REQUEST|SLOT;
                if(service15(0UL)!=(int)(01000UL|SLOT) || !ready15()) return 6;
        }
        /* Dirty/uncertain restoration never calls old RAW armer, and
         * old tagged recovery requests cannot retire directory pins. */
        for(f=0U;f<5U;++f) {
                diag_case_v1981=020U+f;
                fault=f==0U?15U:f==1U?21U:f==2U?26U:f==3U?31U:17U;
                if(!setup15()) return 7;
                if(service15(0UL) || !PROC_TRANSITION(&slots[SLOT]) ||
                    !(tag=u[PROC_FINALIZE_OFFSET]) || VM_PDP6_BASE(&slots[SLOT]) ||
                    proc_sched_cursor!=SLOT || proc_swap_pressure_ticks!=0100UL || arm_calls || bad_call) return 010;
                rc=service15(0400000UL|SLOT);
                if(rc!=-1 || u[PROC_FINALIZE_OFFSET]!=tag || !PROC_TRANSITION(&slots[SLOT]) ||
                    calls15!=1U || arm_calls || bad_call) return 011;
                proc_sched_cursor=PROC_SCHED_SWAP_REQUEST|SLOT;
                if(service15(0UL) || calls15!=1U || u[PROC_FINALIZE_OFFSET]!=tag) return 012;
        }
        /* Service eligibility gate before restore. */
        for(f=0U;f<7U;++f) {
                diag_case_v1981=040U+f; fault=0U;
                if(!setup15()) return 013;
                switch(f) {
                case 0U: proc_sched_cursor=SLOT; break;
                case 1U: slots[SLOT].sched=(kword_t)PROC_STOP<<PROC_STATE_SHIFT; break;
                case 2U: PROC_SET_TRANSITION(&slots[SLOT]); break;
                case 3U: proc_current_slot=SLOT; break;
                case 4U: modes[0]=1UL<<6U; break;
                case 5U: modes[0]|=1UL<<(SLOT*2U); modes[0]&=~(2UL<<(SLOT*2U)); break;
                case 6U: records[SLOT].state=0UL; break;
                }
                if(service15(0UL) || calls15 || loads || alloc_calls || restore_pins || bad_call) return 014;
        }
        /* Direct unlock must reject every dirty/stale owner shape. */
        for(f=0U;f<8U;++f) {
                diag_case_v1981=060U+f; fault=0U;
                if(!setup15()) return 015;
                PROC_SET_TRANSITION(&slots[SLOT]);
                switch(f) {
                case 0U: u[PROC_FINALIZE_OFFSET]=PROC_PURE_BITMAP_FULL_V1980(BASE,0UL); break;
                case 1U: mm_extents[1].meta+=1UL<<MM_PIN_SHIFT; break;
                case 2U: mm_extents[2].meta^=3UL; break;
                case 3U: mm_extents[0].meta^=3UL; break;
                case 4U: ++mm_extents[1].span; break;
                case 5U: u[PROC_CRED_OFFSET]&=~PROC_SWAP_MUTABLE_V1976; break;
                case 6U: u[PROC_SWAP_BACKING_OFFSET]^=1UL; break;
                case 7U: u[PROC_FDCTL_OFFSET]=PROC_FATAL_CLOSE_BIT; break;
                }
                ++diag_cases_v1981;
                if(proc_pure_bitmap_unlock_v1981(SLOT)==MM_OK || !PROC_TRANSITION(&slots[SLOT]) ||
                    restore_unpins || restore_frees || bad_call) return 016;
        }
        mach_pi_restore(saved);
        return 0;
}
