; Native PDP-6 K01: production allocator -> swap service -> MM compaction.
; All leaf callbacks are deterministic fault/pressure probes. No callback
; modifies physical memory ownership or process slot state.

        .text
        .globl main
main:
        ; Case 1: MM_BUSY inside process reclaim must stop one victim.
        movei   1,1
        pushj   17,run_case
        came    1,[-5]
        jrst    fail_1
        move    1,swap_calls
        caie    1,1
        jrst    fail_2
        move    1,out_calls
        caie    1,1
        jrst    fail_3

        ; Case 2: MM_INVAL similarly fails closed, never a second victim.
        movei   1,2
        pushj   17,run_case
        came    1,[-4]
        jrst    fail_4
        move    1,swap_calls
        caie    1,1
        jrst    fail_5
        move    1,out_calls
        caie    1,1
        jrst    fail_6

        ; Case 3: ordinary fragmentation consumes only the finite
        ; candidate list and eventually returns typed fragmentation.
        movei   1,3
        pushj   17,run_case
        came    1,[-2]
        jrst    fail_7
        move    1,out_calls
        caie    1,2
        jrst    fail_8

        ; Case 4: an effective swap permits the next MM allocation.
        movei   1,4
        pushj   17,run_case
        jumpn   1,fail_9
        move    1,swap_calls
        caie    1,1
        jrst    fail_10
        move    1,out_calls
        caie    1,1
        jrst    fail_11

        ; Case 5: MM_BUSY in initial compaction prevents *any* victim.
        movei   1,5
        pushj   17,run_case
        came    1,[-5]
        jrst    fail_12
        skipn   swap_calls
        jrst    check_no_swap
        jrst    fail_13
check_no_swap:
        skipn   out_calls
        jrst    success
        jrst    fail_13
success:
        setz    1,
        popj    17,

run_case:
        movem   1,test_mode
        setzm   alloc_calls
        setzm   fs_calls
        setzm   swap_calls
        setzm   victim_calls
        setzm   out_calls
        setzm   in_swap
        setzm   alloc_ready
        ; C ABI: sixth and fifth arguments on the stack, in that order.
        movei   1,allocated_base
        push    17,1
        setz    1,
        push    17,1
        movei   1,04000
        movei   2,02000
        movei   3,1
        movei   4,1
        pushj   17,mm_alloc_aligned
        sub     17,[2,,2]
        popj    17,

fail_1: movei   1,1
        popj    17,
fail_2: movei   1,2
        popj    17,
fail_3: movei   1,3
        popj    17,
fail_4: movei   1,4
        popj    17,
fail_5: movei   1,5
        popj    17,
fail_6: movei   1,6
        popj    17,
fail_7: movei   1,7
        popj    17,
fail_8: movei   1,010
        popj    17,
fail_9: movei   1,011
        popj    17,
fail_10: movei  1,012
        popj    17,
fail_11: movei  1,013
        popj    17,
fail_12: movei  1,014
        popj    17,
fail_13: movei  1,015
        popj    17,

        .globl mm_alloc_aligned_noreclaim
mm_alloc_aligned_noreclaim:
        aos     alloc_calls
        skipn   alloc_ready
        jrst    no_allocation
        movei   3,020000
        movem   3,(6)
        setz    1,
        popj    17,
no_allocation:
        movni   1,2
        popj    17,

        .globl mm_arena_fits_v1260
mm_arena_fits_v1260:
        movei   1,1
        popj    17,

        .globl fs_memory_reclaim
fs_memory_reclaim:
        aos     fs_calls
        setz    1,
        popj    17,

        .globl proc_swap_reclaim
proc_swap_reclaim:
        aos     swap_calls
        movei   4,1
        movem   4,in_swap
        pushj   17,proc_swap_mres_reclaim_v481
        setzm   in_swap
        popj    17,

        .globl proc_swap_victim
proc_swap_victim:
        aos     victim_calls
        move    4,victim_calls
        caile   4,2
        jrst    no_victim
        move    1,4
        popj    17,
no_victim:
        seto    1,
        popj    17,

        .globl proc_swap_out
proc_swap_out:
        aos     out_calls
        setz    1,
        popj    17,

        .globl mm_compact
mm_compact:
        move    4,test_mode
        skipn   in_swap
        jrst    compact_pre_swap
        caie    4,1
        jrst    compact_case2
        movni   1,5
        popj    17,
compact_case2:
        caie    4,2
        jrst    compact_case4
        movni   1,4
        popj    17,
compact_case4:
        caie    4,4
        jrst    compact_fragmented
        movei   4,1
        movem   4,alloc_ready
        setz    1,
        popj    17,
compact_pre_swap:
        caie    4,5
        jrst    compact_fragmented
        movni   1,5
        popj    17,
compact_fragmented:
        movni   1,2
        popj    17,

        .bss
test_mode:      .block 1
alloc_calls:    .block 1
fs_calls:       .block 1
swap_calls:     .block 1
victim_calls:   .block 1
out_calls:      .block 1
in_swap:        .block 1
alloc_ready:    .block 1
allocated_base: .block 1
        .globl __test_exit
__test_exit:    .block 1
