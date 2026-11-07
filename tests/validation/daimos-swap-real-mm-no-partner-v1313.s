; Native PDP-6: real production MM allocator returns pressure to slot 0.
; A real occupied MM extent is released; retry can then restore the job.
; Disk and exchange admission are test stubs; no full-system claim.
        .text
        .globl main
main:
        movei   1,1
        movem   1,mm_arena_count
        move    1,[010000,,02000]
        movem   1,mm_arenas
        movei   1,4
        movem   1,mm_extent_capacity
        movei   1,1
        movem   1,mm_extent_count
        move    1,[010000,,02000]
        movem   1,mm_extents
        move    1,[03,,3]           ; 8K physical kernel-dynamic extent
        movem   1,mm_extents+1

        movei   1,4
        movem   1,proc_high_slot
        move    1,[0200000000000]
        movem   1,__proc_descriptors+010
        movei   1,__records
        movem   1,proc_swap_records
        movei   1,0402
        movem   1,proc_sched_cursor
        pushj   17,proc_swap_mres_service_v481
        jumpn   1,fail1_v1313
        move    1,proc_swap_pressure_ticks
        caie    1,0100
        jrst    fail2_v1313
        move    1,proc_sched_cursor
        caie    1,2
        jrst    fail3_v1313
        move    1,alloc_fail_v1313
        caie    1,1
        jrst    fail4_v1313
        move    1,pair_calls_v1313
        caie    1,3
        jrst    fail5_v1313
        move    1,mm_extent_count
        caie    1,1
        jrst    fail6_v1313
        skipn   __records+2
        jrst    fail7_v1313
        skipn   __proc_descriptors+010
        jrst    fail8_v1313
        skipn   event_calls_v1313
        jrst    free_owner_v1313
        jrst    fail9_v1313

free_owner_v1313:
        ; Independently free the exact occupied extent through real MM.
        movei   1,02000
        movei   2,3
        movei   3,3
        pushj   17,mm_free
        jumpn   1,fail10_v1313
        skipn   mm_extent_count
        jrst    retry_v1313
        jrst    fail11_v1313

retry_v1313:
        setzm   proc_swap_pressure_ticks
        movei   1,0402
        movem   1,proc_sched_cursor
        pushj   17,proc_swap_mres_service_v481
        caie    1,01002
        jrst    fail12_v1313
        move    1,proc_sched_cursor
        caie    1,01002
        jrst    fail13_v1313
        move    1,mm_extent_count
        caie    1,1
        jrst    fail14_v1313
        move    1,mm_extents
        camn    1,[02000,,010000]
        jrst    check_owner_v1313
        jrst    fail15_v1313
check_owner_v1313:
        move    1,mm_extents+1
        camn    1,[01,,2]
        jrst    check_backing_v1313
        jrst    fail16_v1313
check_backing_v1313:
        skipn   __records+2
        jrst    check_counters_v1313
        jrst    fail17_v1313
check_counters_v1313:
        move    1,alloc_success_v1313
        caie    1,1
        jrst    fail18_v1313
        move    1,alloc_fail_v1313
        caie    1,1
        jrst    fail19_v1313
        move    1,fs_reclaim_calls_v1313
        caie    1,2
        jrst    fail20_v1313
        move    1,swap_reclaim_calls_v1313
        caie    1,1
        jrst    fail21_v1313
        skipn   event_calls_v1313
        jrst    success_v1313
        jrst    fail22_v1313
success_v1313:
        setz    1,
        popj    17,
fail1_v1313: movei 1,1
        popj 17,
fail2_v1313: movei 1,2
        popj 17,
fail3_v1313: movei 1,3
        popj 17,
fail4_v1313: movei 1,4
        popj 17,
fail5_v1313: movei 1,5
        popj 17,
fail6_v1313: movei 1,6
        popj 17,
fail7_v1313: movei 1,7
        popj 17,
fail8_v1313: movei 1,010
        popj 17,
fail9_v1313: movei 1,011
        popj 17,
fail10_v1313: movei 1,012
        popj 17,
fail11_v1313: movei 1,013
        popj 17,
fail12_v1313: movei 1,014
        popj 17,
fail13_v1313: movei 1,015
        popj 17,
fail14_v1313: movei 1,016
        popj 17,
fail15_v1313: movei 1,017
        popj 17,
fail16_v1313: movei 1,020
        popj 17,
fail17_v1313: movei 1,021
        popj 17,
fail18_v1313: movei 1,022
        popj 17,
fail19_v1313: movei 1,023
        popj 17,
fail20_v1313: movei 1,024
        popj 17,
fail21_v1313: movei 1,025
        popj 17,
fail22_v1313: movei 1,026
        popj 17,

; The slot-0 service body is unchanged production assembler. Its
; proc_swap_in dependency allocates from the real production MM,
; but intentionally models the disk transfer as a test-only commit.
        .globl proc_swap_in
proc_swap_in:
        push    17,1
        push    17,[0]
        movei   2,(17)
        push    17,2
        push    17,[1]                ; MM_ALLOC_HIGH
        movei   1,02000
        movei   2,02000
        movei   3,1                    ; MM_TYPE_PROCESS
        movei   4,2                    ; target slot
        pushj   17,mm_alloc_aligned
        sub     17,[2,,2]
        jumpe   1,swap_alloc_ok_v1313
        ; In this full-arena scenario the *actual* allocator must
        ; report typed physical NOMEM, not an invalid argument,
        ; failed rollback or a fabricated pressure result.
        camn    1,[-1]
        jrst    swap_alloc_pressure_v1313
        sub     17,[1,,1]
        pop     17,2
        seto    1,
        popj    17,
swap_alloc_pressure_v1313:
        aos     alloc_fail_v1313
        sub     17,[1,,1]
        pop     17,2
        movei   1,1                    ; retryable resource pressure
        popj    17,
swap_alloc_ok_v1313:
        aos     alloc_success_v1313
        pop     17,2                   ; real physical allocated base
        pop     17,3                   ; original requested slot
        movem   2,__restored_base_v1313
        setzm   __records+2            ; model completed disk transfer
        setz    1,
        popj    17,

        .globl proc_swap_exchange_pair_v826
proc_swap_exchange_pair_v826:
        aos     pair_calls_v1313
        seto    1,                    ; no eligible physical peer
        popj   17,
        .globl proc_swap_exchange_execute_v832
proc_swap_exchange_execute_v832:
        aos     exchange_calls_v1313
        seto    1,
        popj   17,
        .globl fs_memory_reclaim
fs_memory_reclaim:
        aos     fs_reclaim_calls_v1313
        seto    1,                    ; no movable filesystem cache
        popj   17,
        .globl proc_swap_reclaim
proc_swap_reclaim:
        aos     swap_reclaim_calls_v1313
        seto    1,                    ; no reclaimable resident peer
        popj   17,
        .globl mm_move_extent
mm_move_extent:
        movei   1,1                   ; impossible to relocate fixed extent
        popj   17,
        .globl proc_event_apply
proc_event_apply:
        aos     event_calls_v1313
        setz    1,
        popj   17,
        .globl kret_zero
kret_zero:
        setz    1,
        popj   17,
        .globl kret_neg1
kret_neg1:
        seto    1,
        popj   17,

        .data
        .globl mm_arena_count
mm_arena_count: .word 0
        .globl mm_arenas
mm_arenas: .block 3
        .globl mm_extent_count
mm_extent_count: .word 0
        .globl mm_extent_capacity
mm_extent_capacity: .word 0
        .globl mm_extents
mm_extents: .block 010
        .globl proc_high_slot
proc_high_slot: .word 0
        .globl proc_sched_cursor
proc_sched_cursor: .word 0
        .globl proc_swap_pressure_ticks
proc_swap_pressure_ticks: .word 0
        .globl proc_swap_records
proc_swap_records: .word 0
        .globl proc_table
proc_table: .word __proc_descriptors
        .globl kconst_1_1
kconst_1_1: .word 1,,1
__records: .word 0
        .word 0
        .word 012345
        .word 0
__restored_base_v1313: .word 0
        .globl alloc_fail_v1313
alloc_fail_v1313: .word 0
        .globl alloc_success_v1313
alloc_success_v1313: .word 0
        .globl pair_calls_v1313
pair_calls_v1313: .word 0
        .globl exchange_calls_v1313
exchange_calls_v1313: .word 0
        .globl fs_reclaim_calls_v1313
fs_reclaim_calls_v1313: .word 0
        .globl swap_reclaim_calls_v1313
swap_reclaim_calls_v1313: .word 0
        .globl event_calls_v1313
event_calls_v1313: .word 0
        .bss
__proc_descriptors: .block 014
        .globl __test_exit
__test_exit: .block 1
