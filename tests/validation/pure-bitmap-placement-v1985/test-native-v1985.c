/* Real prefix lease, placement leaf, FULL and common terminal gateway. */
#define LOW_V1985 040600UL
#define MODE3_V1985 ((1UL<<6U)|(3UL<<(2U*SLOT)))
kword_t diag_case_v1985, diag_cases_v1985;
static unsigned int place_fault, place_calls;
static kword_t *const low_v1985=(kword_t *)LOW_V1985;
int place_mm_v1985(kword_t base,unsigned int slot,kword_t words,kword_t lengths,kword_t target)
{
        int rc;
        ++place_calls;
        if(base!=BASE || slot!=SLOT || words!=WORDS || target!=placed_base_v1985 ||
            lengths!=((PREFIX<<18U)|PACKED_WORDS) || (pi_state_v1978()&0200UL) ||
            u[PROC_FINALIZE_OFFSET]!=PROC_PURE_BITMAP_PLACE_V1985(target,PACKED_WORDS)) bad_call=040U;
        if(place_fault==1U) return MM_ERR_BUSY;
        if(place_fault==2U) return MM_OK;
        rc=mm_pure_bitmap_place_v1985(base,slot,words,lengths,target);
        if(place_fault==4U && rc==MM_OK) mm_extents[1].meta^=3UL;
        return place_fault>=3U ? MM_ERR_BUSY:rc;
}
int free_dispatch_v1985(kword_t base,unsigned int kind,unsigned int owner)
{
        return kind==MM_TYPE_PROCESS ? free_v1980(base,kind,owner):term_free_v1982(base,kind,owner);
}
static void reset17(void)
{
        unsigned int i;
        reset13(0U);
        placed_base_v1985=LOW_V1985;
        place_fault=place_calls=0U;
        fault=loads=payload_reads=finish_calls=alloc_calls=restore_pins=restore_unpins=restore_frees=decode_calls=verify_calls=0U;
        target_addr=0UL;
        term_fault=term_calls=0U;
        for(i=0U;i<PACKED_WORDS;++i) low_v1985[i]=GUARD^0777UL;
        low_v1985[-1]=low_v1985[PACKED_WORDS]=GUARD;
}
static int placed17(void)
{
        return !bad_call && !PROC_TRANSITION(&slots[SLOT]) && !VM_PDP6_BASE(&slots[SLOT]) &&
            VM_SPACE_WORDS(&slots[SLOT])==WORDS && modes[0]==MODE3_V1985 &&
            records[SLOT].state==BACKING && u[PROC_SWAP_BACKING_OFFSET]==BACKING &&
            u[PROC_CRED_OFFSET]==IDENTITY && !u[PROC_FINALIZE_OFFSET] &&
            mm_pure_table_v1922()==MM_OK &&
            proc_pure_owner_v1918(SLOT,MM_TYPE_PACKED_PROCESS,LOW_V1985,PACKED_WORDS,0U)==LOW_V1985 &&
            pbmd_verify_v1979(SUFFIX,RAW,LOW_V1985,PACKED_WORDS)==MM_OK && raw_ok() &&
            low_v1985[-1]==GUARD && low_v1985[PACKED_WORDS]==GUARD;
}
static int drop17(void)
{
        ++diag_cases_v1985;
        return proc_pure_bitmap_drop_v1979(SLOT);
}
int main(void)
{
        static const kword_t invalid[]={0UL,040601UL,040200UL,050200UL,052000UL,020000UL,01000000UL,047600UL};
        unsigned int f,i;
        kword_t saved=mach_pi_disable(), b, span, meta;
        int rc;
        install_d6_v1980();
        for(f=0U;f<5U;++f) {
                diag_case_v1985=f+1U; reset17(); place_fault=f;
                mm_extent_capacity=3U; /* full descriptor table */
                rc=drop17();
                if(place_calls!=1U || commit_calls || bad_call || mm_extent_count!=3) return 1;
                if(f==0U || f==3U) { if(rc || !placed17() || rebase_calls || unpin_calls) return 2; }
                else if(f==1U) { if(rc || !raw13() || rebase_calls!=1U) return 3; }
                else {
                        if(rc!=MM_ERR_BUSY || !PROC_TRANSITION(&slots[SLOT]) ||
                            VM_PDP6_BASE(&slots[SLOT])!=BASE || modes[0]!=(1UL<<6U) ||
                            u[PROC_FINALIZE_OFFSET]!=PROC_PURE_BITMAP_PLACE_V1985(LOW_V1985,PACKED_WORDS) ||
                            rebase_calls || unpin_calls || legacy_gate_v1978(SLOT,0U)) return 4;
                }
        }
        /* No lower free span: original placement remains valid. */
        diag_case_v1985=010U; reset17(); fill_arenas();
        if(drop17() || place_calls || commit_calls!=1U || !bitmap_ok()) return 5;
        /* Foreign descriptor between source and destination, full table.
         * Commit must shift the original descriptor down, preserving
         * every foreign extent and its payload. */
        diag_case_v1985=011U; reset17();
        if(prepare(SLOT)) return 6;
        mm_extents[3]=mm_extents[2]; mm_extents[2]=mm_extents[1];
        extent(1,042000UL,0100UL,MM_TYPE_KERNEL_DYNAMIC,0700U);
        *(kword_t *)042000UL=GUARD;
        mm_extent_capacity=mm_extent_count=4;
        span=mm_extents[1].span; meta=mm_extents[1].meta;
        ++diag_cases_v1985;
        if(commit13() || !placed17() || mm_extent_count!=4 || mm_extents[2].span!=span ||
            mm_extents[2].meta!=meta || *(kword_t *)042000UL!=GUARD ||
            MM_EXTENT_BASE(&mm_extents[3])!=BASE+WORDS) return 7;
        /* Several intervening descriptors, including same numeric owner
         * in the independent MODULE/KERNEL_DYNAMIC namespaces. */
        diag_case_v1985=012U; reset17();
        if(prepare(SLOT)) return 023;
        mm_extents[5]=mm_extents[2]; mm_extents[4]=mm_extents[1];
        extent(1,042000UL,0100UL,MM_TYPE_KERNEL_DYNAMIC,0700U);
        extent(2,044000UL,0200UL,MM_TYPE_MODULE,SLOT);
        extent(3,046000UL,0300UL,MM_TYPE_KERNEL_DYNAMIC,SLOT);
        for(i=1U;i<=3U;++i) {
                before[i]=mm_extents[i];
                *(kword_t *)MM_EXTENT_BASE(&mm_extents[i])=GUARD^i;
        }
        mm_extent_capacity=mm_extent_count=6;
        ++diag_cases_v1985;
        if(mm_pure_bitmap_place_v1985(BASE,SLOT,WORDS,(PREFIX<<18U)|PACKED_WORDS,041600UL)==MM_OK ||
            !raw_ok() || *(kword_t *)042000UL!=(GUARD^1U)) return 024;
        ++diag_cases_v1985;
        if(commit13() || !placed17() || mm_extent_count!=6 || MM_EXTENT_BASE(&mm_extents[5])!=BASE+WORDS) return 025;
        for(i=1U;i<=3U;++i) if(mm_extents[i+1U].span!=before[i].span ||
            mm_extents[i+1U].meta!=before[i].meta || *(kword_t *)MM_EXTENT_BASE(&mm_extents[i+1U])!=(GUARD^i)) return 026;
        /* Invalid destination before any copy or table mutation. */
        for(f=0U;f<sizeof(invalid)/sizeof(invalid[0])+4U;++f) {
                diag_case_v1985=020U+f; reset17();
                if(prepare(SLOT)) return 010;
                b=f<sizeof(invalid)/sizeof(invalid[0])?invalid[f]:LOW_V1985;
                if(f==8U) mm_extents[1].meta+=1UL<<MM_PIN_SHIFT;
                if(f==9U) mm_extents[2].meta=(1UL<<18U)|SLOT;
                if(f==10U) mm_extents[0].span=(01000UL<<18U)|UAREA;
                if(f==11U) mm_extent_capacity=2U;
                for(i=0U;i<3U;++i) before[i]=mm_extents[i];
                ++diag_cases_v1985;
                if(mm_pure_bitmap_place_v1985(BASE,SLOT,WORDS,(PREFIX<<18U)|PACKED_WORDS,b)==MM_OK ||
                    pbmd_verify_v1979(SUFFIX,RAW,BASE,PACKED_WORDS)!=MM_OK || !raw_ok() || low_v1985[-1]!=GUARD || low_v1985[PACKED_WORDS]!=GUARD) return 011;
                for(i=0U;i<3U;++i) if(before[i].span!=mm_extents[i].span || before[i].meta!=mm_extents[i].meta) return 012;
                for(i=0U;i<PACKED_WORDS;++i) if(low_v1985[i]!=(GUARD^0777UL)) return 013;
        }
        /* v1996: with no lower gap, use a higher leading fragment.
         * The original neighbor is shifted, not changed. The table is
         * full; there is no room for a temporary allocation. */
        for(f=0U;f<4U;++f) {
                kword_t *high=(kword_t *)052200UL;
                diag_case_v1985=0100U+f; reset17(); fill_arenas();
                mm_arenas[1]=((WORDS+0200UL+04000UL)<<18U)|BASE;
                placed_base_v1985=052200UL; place_fault=f;
                mm_extent_capacity=3U;
                before[2]=mm_extents[2];
                for(i=0U;i<=PACKED_WORDS;++i) high[i]=GUARD;
                rc=drop17();
                if(place_calls!=1U || commit_calls || bad_call ||
                    mm_extent_count!=3 || !raw_ok() || high[PACKED_WORDS]!=GUARD) return 027;
                if(f==0U || f==3U) {
                        if(rc || PROC_TRANSITION(&slots[SLOT]) || VM_PDP6_BASE(&slots[SLOT]) ||
                            modes[0]!=MODE3_V1985 || u[PROC_FINALIZE_OFFSET] ||
                            u[PROC_SWAP_BACKING_OFFSET]!=BACKING || rebase_calls || unpin_calls ||
                            mm_pure_table_v1922()!=MM_OK ||
                            mm_extents[1].span!=before[2].span || mm_extents[1].meta!=before[2].meta ||
                            proc_pure_owner_v1918(SLOT,MM_TYPE_PACKED_PROCESS,placed_base_v1985,PACKED_WORDS,0U)!=placed_base_v1985 ||
                            pbmd_verify_v1979(SUFFIX,RAW,placed_base_v1985,PACKED_WORDS)!=MM_OK) return 030;
                        /* Reuse and overwrite the old APR before FULL or
                         * exact PREVM terminal retry at the higher owner. */
                        for(i=0U;i<PACKED_WORDS;++i) packed_copy[i]=high[i];
                        mm_arenas[1]=((WORDS+0200UL+PACKED_WORDS)<<18U)|BASE;
                        mm_extent_capacity=MM_MAX_EXTENTS;
                        if(mm_alloc_aligned_noreclaim(WORDS,02000UL,MM_TYPE_KERNEL_DYNAMIC,0700U,MM_ALLOC_LOW,&b)!=MM_OK || b!=BASE) return 043;
                        for(i=0U;i<WORDS;++i) image[i]=GUARD^077777UL;
                        if(mm_free(b,MM_TYPE_KERNEL_DYNAMIC,0700U)) return 044;
                        PROC_SET_TRANSITION(&slots[SLOT]); slots[SLOT].sched=(kword_t)PROC_SRUN<<PROC_STATE_SHIFT;
                        if(f==0U) {
                                if(restore14() || bad_call || !full_ok(BASE) || VM_PDP6_BASE(&slots[SLOT])!=BASE ||
                                    modes[0]!=(1UL<<6U) || PROC_TRANSITION(&slots[SLOT]) || u[PROC_FINALIZE_OFFSET] ||
                                    proc_pure_owner_v1918(SLOT,MM_TYPE_PROCESS,BASE,WORDS,0U)!=BASE || mm_extent_count!=3U) return 045;
                        } else {
                                u[PROC_BRK_OFFSET]=HEAP; term_fault=1U;
                                if(detach16()==MM_OK || !held16(TMARK) || term_calls!=1U) return 046;
                                prevm_v1982(&slots[SLOT],012345U); term_fault=0U;
                                if(detach16() || !retired16(LIFE|012345UL) || term_calls!=2U) return 047;
                        }
                } else if(f==1U) {
                        if(rc || !raw13() || rebase_calls!=1U) return 031;
                } else if(rc!=MM_ERR_BUSY || !PROC_TRANSITION(&slots[SLOT]) ||
                    VM_PDP6_BASE(&slots[SLOT])!=BASE || modes[0]!=(1UL<<6U) ||
                    u[PROC_FINALIZE_OFFSET]!=PROC_PURE_BITMAP_PLACE_V1985(placed_base_v1985,PACKED_WORDS) ||
                    rebase_calls || unpin_calls || legacy_gate_v1978(SLOT,0U)) return 032;
                if(f==1U || f==2U) for(i=0U;i<PACKED_WORDS;++i) if(high[i]!=GUARD) return 033;
        }
        /* Higher destination after several intervening owners. Reject
         * both overlap at the target start and overlap at its end. */
        diag_case_v1985=0110U; reset17(); fill_arenas();
        mm_arenas[1]=((WORDS+0200UL+04000UL)<<18U)|BASE;
        if(prepare(SLOT)) return 034;
        extent(3,052200UL,0200UL,MM_TYPE_MODULE,SLOT);
        extent(4,052400UL,0200UL,MM_TYPE_KERNEL_DYNAMIC,SLOT);
        extent(5,053000UL,0200UL,MM_TYPE_KERNEL_DYNAMIC,0700U);
        mm_extent_count=mm_extent_capacity=6U;
        for(i=2U;i<6U;++i) before[i]=mm_extents[i];
        ++diag_cases_v1985;
        if(mm_pure_bitmap_place_v1985(BASE,SLOT,WORDS,(PREFIX<<18U)|PACKED_WORDS,052400UL)==MM_OK) return 035;
        /* A short gap beginning at 052600 has room for only 128 words. */
        ++diag_cases_v1985;
        if(mm_pure_bitmap_place_v1985(BASE,SLOT,WORDS,(PREFIX<<18U)|PACKED_WORDS,052600UL)==MM_OK ||
            pbmd_verify_v1979(SUFFIX,RAW,BASE,PACKED_WORDS)!=MM_OK || !raw_ok() ||
            proc_pure_owner_v1918(SLOT,MM_TYPE_PROCESS,BASE,WORDS,1U)!=BASE) return 036;
        for(i=2U;i<6U;++i) if(mm_extents[i].span!=before[i].span || mm_extents[i].meta!=before[i].meta) return 037;
        placed_base_v1985=053200UL;
        ++diag_cases_v1985;
        if(commit13() || bad_call || mm_extent_count!=6U || mm_pure_table_v1922()!=MM_OK ||
            proc_pure_owner_v1918(SLOT,MM_TYPE_PACKED_PROCESS,placed_base_v1985,PACKED_WORDS,0U)!=placed_base_v1985 ||
            pbmd_verify_v1979(SUFFIX,RAW,placed_base_v1985,PACKED_WORDS)!=MM_OK) return 040;
        for(i=2U;i<6U;++i) if(mm_extents[i-1U].span!=before[i].span || mm_extents[i-1U].meta!=before[i].meta) return 041;
        /* Do not trade a free aligned APR for a higher bitmap. */
        diag_case_v1985=0111U; reset17(); fill_arenas();
        mm_arenas[1]=((2U*WORDS+04000UL)<<18U)|BASE;
        extent(2,BASE+WORDS,WORDS,MM_TYPE_PROCESS,2U);
        if(drop17() || place_calls || commit_calls!=1U) return 042;
        /* Exact old APR can be reclaimed and overwritten, including
         * original candidate and suffix. Then restore from moved owner. */
        for(f=0U;f<4U;++f) {
                diag_case_v1985=040U+f; reset17();
                if(drop17() || !placed17()) return 014;
                for(i=0U;i<PACKED_WORDS;++i) packed_copy[i]=low_v1985[i];
                /* Restrict managed arenas to force reuse of original APR. */
                mm_arena_count=2;
                mm_arenas[0]=((LOW_V1985+PACKED_WORDS-UAREA)<<18U)|UAREA;
                mm_arenas[1]=((WORDS+0200UL)<<18U)|BASE;
                if(mm_alloc_aligned_noreclaim(WORDS,02000UL,MM_TYPE_KERNEL_DYNAMIC,0700U,MM_ALLOC_LOW,&b)!=MM_OK || b!=BASE) return 015;
                for(i=0U;i<WORDS;++i) image[i]=GUARD^077777UL;
                if(mm_free(b,MM_TYPE_KERNEL_DYNAMIC,0700U)) return 016;
                PROC_SET_TRANSITION(&slots[SLOT]); slots[SLOT].sched=(kword_t)PROC_SRUN<<PROC_STATE_SHIFT;
                fault=f==1U?1U:f==2U?2U:0U;
                if(f==3U) { /* Exact terminal retry at moved source. */
                        u[PROC_BRK_OFFSET]=HEAP; term_fault=1U;
                        if(detach16()==MM_OK || !held16(TMARK) || term_calls!=1U) return 017;
                        prevm_v1982(&slots[SLOT],012345U); term_fault=0U;
                        if(detach16() || !retired16(LIFE|012345UL) || term_calls!=2U) return 020;
                        continue;
                }
                rc=restore14();
                if(f==2U) {
                        if(rc==MM_OK || !packed_ok() || !PROC_TRANSITION(&slots[SLOT]) || u[PROC_FINALIZE_OFFSET] ||
                            proc_pure_bitmap_unlock_v1981(SLOT) || PROC_TRANSITION(&slots[SLOT])) return 021;
                        PROC_SET_TRANSITION(&slots[SLOT]); fault=0U; rc=restore14();
                }
                if(rc || bad_call || VM_PDP6_BASE(&slots[SLOT])!=BASE || PROC_TRANSITION(&slots[SLOT]) ||
                    modes[0]!=(1UL<<6U) || !full_ok(BASE) || mm_extent_count!=3 ||
                    proc_pure_owner_v1918(SLOT,MM_TYPE_PROCESS,BASE,WORDS,0U)!=BASE ||
                    u[PROC_SWAP_BACKING_OFFSET] || u[PROC_FINALIZE_OFFSET]) return 022;
        }
        mach_pi_restore(saved);
        return 0;
}
