/* Native staged dirty DROP rollback. Original MM, codec, service,
 * idle armer, deadline and retry scan; named fault wrappers only. */
kword_t diag_case_v1993, diag_cases_v1993;

static void reset23(void)
{
        reset17();
        slots[2].meta=slots[2].vm_state=slots[2].sched=0UL;
        slots[3].meta=slots[3].vm_state=slots[3].sched=0UL;
        records[2].state=records[3].state=0UL;
        proc_sched_cursor=proc_swap_pressure_ticks=proc_sched_kick=0UL;
        proc_timer_clock=0100UL; proc_finish_last_tick_v881=0UL;
        terms20=discards20=services20=0U;
        u[PROC_BRK_OFFSET]=HEAP;
}

/* Independent tag oracle, no production packing macros. */
static kword_t tag23(unsigned int phase)
{
        return ((phase?013UL:3UL)<<29U)|((SUFFIX>>7U)<<18U)|
            0600000UL|((WORDS/02000UL)<<7U)|((IDENTITY>>27U)<<2U)|phase;
}

static int held23(unsigned int phase,unsigned int packed)
{
        return raw_ok() && PROC_TRANSITION(&slots[SLOT]) &&
            u[PROC_FINALIZE_OFFSET]==tag23(phase) &&
            records[SLOT].state==BACKING &&
            u[PROC_SWAP_BACKING_OFFSET]==BACKING &&
            u[PROC_CRED_OFFSET]==IDENTITY && u[PROC_BRK_OFFSET]==HEAP &&
            VM_PDP6_BASE(&slots[SLOT])==(packed?0UL:BASE) &&
            modes[0]==((1UL<<6U)|(packed?2UL<<2U:0UL)) &&
            proc_pure_owner_v1918(SLOT,packed?MM_TYPE_PACKED_PROCESS:MM_TYPE_PROCESS,
                packed?SUFFIX:BASE,packed?RAW:WORDS,1U)!=0UL &&
            mm_extent_count==3 && !bad_call;
}
static int clean23(void)
{
        return raw13() && u[PROC_BRK_OFFSET]==HEAP && !bad_call &&
            !terms20 && !discards20;
}
static int drop23(void)
{
        ++diag_cases_v1993;
        return proc_pure_bitmap_drop_v1979(SLOT);
}

int main(void)
{
        unsigned int f,g,ops;
        kword_t saved=mach_pi_disable(),tag,span,meta,back;
        /* Healthy marked directory, ordinary no-gain RAW, and old
         * RAW retry retain their existing representation and routing. */
        diag_case_v1993=0100U; reset23();
        if(drop23() || !placed17() || proc_finish_last_tick_v881) return 032;
        diag_case_v1993=0101U; reset23(); shape=1U;
        {
                kword_t i;
                for(i=0UL;i<RAW;++i) image[PREFIX+i]=raw_value(i);
        }
        if(drop23() || !clean23() || proc_finish_last_tick_v881) return 033;
        PROC_SET_TRANSITION(&slots[SLOT]);
        u[PROC_FINALIZE_OFFSET]=PROC_PURE_FULL_ESCROW_V1917(SUFFIX,0UL);
        if(service20(0400000UL|SLOT) || !clean23()) return 034;
        /* Real allocator pressure invokes the original reclaim service,
         * not a direct test-only cancellation entry. */
        diag_case_v1993=0102U; reset23(); fill_arenas();
        PROC_CLEAR_TRANSITION(&slots[SLOT]);
        encode_fault=2U; rebase_fault=1U;
        if(proc_pure_mres_reclaim_v1612(PREFIX,1UL,0U)!=MM_ERR_BUSY ||
            !held23(1U,0U) || !clock20(0100UL,020UL)) return 035;
        rebase_fault=0U;
        if(!due20(0120UL) || !clean23() || proc_finish_last_tick_v881>>18U) return 036;
        /* Partial write and failed candidate commit each use exact
         * RAW fallback; failed pin retirement never unlocks dirty text. */
        for(g=0U;g<2U;++g) {
                for(f=0U;f<4U;++f) {
                        diag_case_v1993=1U+g*010U+f;
                        reset23();
                        if(g) place_fault=1U;
                        else encode_fault=2U;
                        if(f==1U) rebase_fault=1U;
                        if(f==2U) unpin_fault=1U;
                        if(f==3U) { rebase_fault=2U; unpin_fault=2U; }
                        if(f==0U || f==3U) {
                                if(drop23() || !clean23() || rebase_calls!=1U ||
                                    unpin_calls!=1U || proc_finish_last_tick_v881) return 1;
                                continue;
                        }
                        if(drop23()!=MM_ERR_BUSY || !held23(f,f==2U) ||
                            !clock20(0100UL,020UL) || legacy_gate_v1978(SLOT,
                            f==1U?PROC_STORAGE_RESIDENT:PROC_STORAGE_PACKED)) return 2;
                        /* Wake while held; no retry before due, no
                         * new pin or backing access, even if unmounted. */
                        slots[SLOT].sched=(kword_t)PROC_SRUN<<PROC_STATE_SHIFT;
                        roots[0]=0UL;
                        proc_sched_cursor=PROC_SCHED_SWAP_REQUEST|2U;
                        tag=u[PROC_FINALIZE_OFFSET];
                        if(due20(0117UL) || services20 || !held23(f,f==2U)) return 3;
                        if(!due20(0120UL) || services20!=1U ||
                            !clock20(0120UL,040UL) || !held23(f,f==2U) ||
                            u[PROC_FINALIZE_OFFSET]!=tag || pin_calls!=1U) return 4;
                        rebase_fault=unpin_fault=0U;
                        if(!due20(0160UL) || services20!=2U || !clean23() ||
                            proc_finish_last_tick_v881>>18U || pin_calls!=1U ||
                            proc_sched_cursor!=(PROC_SCHED_SWAP_REQUEST|2U)) return 5;
                }
        }
        /* An uncertain owner revokes authority. Fixing test metadata
         * later cannot turn a HOLD into a newly authorized operation. */
        for(f=0U;f<3U;++f) {
                diag_case_v1993=030U+f; reset23(); encode_fault=2U;
                rebase_fault=1U;
                if(drop23()!=MM_ERR_BUSY || !held23(1U,0U)) return 6;
                span=mm_extents[1].span; meta=mm_extents[1].meta;
                if(f==0U) mm_extents[1].span-=1UL<<18U;
                if(f==1U) mm_extents[1].meta^=3UL;
                if(f==2U) mm_extents[1].meta+=1UL<<MM_PIN_SHIFT;
                ops=rebase_calls; rebase_fault=0U;
                if(!due20(0120UL) || rebase_calls!=ops ||
                    u[PROC_FINALIZE_OFFSET]!=tag23(0U)) return 7;
                mm_extents[1].span=span; mm_extents[1].meta=meta;
                if(!due20(0160UL) || services20!=1U || rebase_calls!=ops ||
                    proc_finish_last_tick_v881>>18U || !held23(0U,0U)) return 010;
                /* Even an unpinned HOLD cannot enter legacy unlock. */
                if(mm_unpin(BASE)!=MM_OK || legacy_gate_v1978(SLOT,0U) ||
                    !PROC_TRANSITION(&slots[SLOT])) return 011;
        }
        /* Post-mutation identity loss must prevent a later MM action. */
        for(f=0U;f<2U;++f) {
                diag_case_v1993=040U+f; reset23(); encode_fault=2U;
                if(f) unpin_fault=3U;
                else rebase_fault=3U;
                if(drop23()!=MM_ERR_BUSY || !PROC_TRANSITION(&slots[SLOT]) ||
                    u[PROC_FINALIZE_OFFSET]!=tag23(0U) ||
                    proc_finish_last_tick_v881 || (f?unpin_calls!=1U:unpin_calls!=0U) ||
                    (!f && (VM_PDP6_BASE(&slots[SLOT])!=BASE ||
                     proc_storage_expect_v30(SLOT,PROC_STORAGE_RESIDENT)))) return 012;
        }
        /* Unrecognized dirty pre-commit quarantine must not be adopted
         * by a later command. A refused false-success placement remains
         * in the old exact candidate escrow. */
        diag_case_v1993=050U; reset23(); place_fault=2U;
        if(drop23()!=MM_ERR_BUSY || !PROC_TRANSITION(&slots[SLOT]) ||
            rebase_calls || unpin_calls || proc_finish_last_tick_v881) return 013;
        tag=u[PROC_FINALIZE_OFFSET];
        if(service20(0400000UL|SLOT)==MM_OK || u[PROC_FINALIZE_OFFSET]!=tag ||
            rebase_calls || unpin_calls) return 014;
        /* Exact saved backing mismatch refuses without MM mutation.
         * This is not authorization to adopt a different executable. */
        diag_case_v1993=051U; reset23(); encode_fault=2U; unpin_fault=1U;
        if(drop23()!=MM_ERR_BUSY || !held23(2U,1U)) return 015;
        back=records[SLOT].state;
        records[SLOT].state^=1UL;
        ops=unpin_calls;
        if(service20(0400000UL|SLOT)==MM_OK || unpin_calls!=ops ||
            u[PROC_FINALIZE_OFFSET]!=tag23(0U)) return 016;
        records[SLOT].state=back;
        if(service20(0400000UL|SLOT)==MM_OK || unpin_calls!=ops ||
            u[PROC_FINALIZE_OFFSET]!=tag23(0U)) return 023;
        /* HOLD mode2 must not be unlocked even with zero pins. */
        if(mm_unpin(SUFFIX)!=MM_OK || legacy_gate_v1978(SLOT,2U) ||
            !PROC_TRANSITION(&slots[SLOT])) return 017;
        /* A foreign pin or owner on the already-published RAW
         * suffix must not authorize any unpin, even if later repaired. */
        for(f=0U;f<3U;++f) {
                diag_case_v1993=060U+f; reset23(); encode_fault=2U;
                unpin_fault=1U;
                if(drop23()!=MM_ERR_BUSY || !held23(2U,1U)) return 024;
                meta=mm_extents[1].meta; span=mm_extents[1].span;
                if(f==0U) mm_extents[1].meta+=1UL<<MM_PIN_SHIFT;
                if(f==1U) mm_extents[1].meta^=3UL;
                if(f==2U) mm_extents[1].span-=1UL<<18U;
                ops=unpin_calls; unpin_fault=0U;
                if(!due20(0120UL) || unpin_calls!=ops ||
                    u[PROC_FINALIZE_OFFSET]!=tag23(0U)) return 025;
                mm_extents[1].meta=meta; mm_extents[1].span=span;
                if(!due20(0160UL) || services20!=1U || unpin_calls!=ops ||
                    proc_finish_last_tick_v881>>18U || !held23(0U,1U)) return 026;
        }
        /* Original geometry and provider credential are encoded in
         * escrow, not rediscovered from current process metadata.
         * Even coherent geometry changes must not authorize rebase. */
        for(f=0U;f<3U;++f) {
                diag_case_v1993=070U+f; reset23(); encode_fault=2U;
                rebase_fault=1U;
                if(drop23()!=MM_ERR_BUSY || !held23(1U,0U)) return 027;
                if(f==0U) u[PROC_CRED_OFFSET]^=PROC_SWAP_MOUNT_EXT_BIT;
                if(f==1U) u[PROC_CRED_OFFSET]^=1UL<<PROC_SWAP_PROVIDER_SHIFT_V1924;
                if(f==2U) {
                        /* The new VM and MM descriptor agree; the
                         * original escrow length is the only mismatch. */
                        mm_extent_count=2U;
                        VM_PDP6_SET_SPACE(&slots[SLOT],WORDS+02000UL,BASE);
                        mm_extents[1].span=((WORDS+02000UL)<<18U)|BASE;
                }
                ops=rebase_calls; rebase_fault=0U;
                if(!due20(0120UL) || rebase_calls!=ops ||
                    u[PROC_FINALIZE_OFFSET]!=tag23(0U)) return 030;
                u[PROC_CRED_OFFSET]=IDENTITY;
                VM_PDP6_SET_SPACE(&slots[SLOT],WORDS,BASE);
                mm_extents[1].span=(WORDS<<18U)|BASE;
                mm_extent_count=3U;
                if(!due20(0160UL) || services20!=1U || rebase_calls!=ops ||
                    proc_finish_last_tick_v881>>18U || !held23(0U,0U)) return 031;
        }
        /* A FULL SOURCE tag whose encoded count happens to have the
         * DROP length/credential/phase fields must never become DROP
         * authority when the storage mode is inconsistent. */
        diag_case_v1993=073U; reset23(); encode_fault=2U; unpin_fault=1U;
        if(drop23()!=MM_ERR_BUSY || !held23(2U,1U)) return 037;
        tag=PBR_TAG_V1989(SUFFIX,((WORDS/02000UL)<<7U)|
            ((IDENTITY>>27U)<<2U)|2UL,PBR_SOURCE_V1989);
        u[PROC_FINALIZE_OFFSET]=tag;
        ops=unpin_calls; unpin_fault=0U;
        if(service20(0400000UL|SLOT)==MM_OK || unpin_calls!=ops ||
            u[PROC_FINALIZE_OFFSET]!=tag ||
            !PROC_TRANSITION(&slots[SLOT])) return 040;
        /* Foreign current slot and malformed command cannot recover. */
        diag_case_v1993=052U; reset23(); encode_fault=2U; rebase_fault=1U;
        if(drop23()!=MM_ERR_BUSY || !held23(1U,0U)) return 020;
        proc_current_slot=2UL; ops=rebase_calls;
        if(service20(0400000UL|SLOT)==MM_OK || service20(0400400UL|SLOT)==MM_OK ||
            rebase_calls!=ops || !held23(1U,0U)) return 021;
        proc_current_slot=0UL; rebase_fault=0U;
        if(!due20(0120UL) || !clean23()) return 022;
        mach_pi_restore(saved);
        return 0;
}
