; v1316: run actual production proc_swap_in, MM pin/unpin, storage mode,
; and backstore-free accounting with a test-only physical disk reader.
; Only disk I/O and exchange candidate admission are test stubs.
        .text
        .globl main
main:
        movei   1,1
        movem   1,mm_arena_count
        move    1,[010000,,0300000]
        movem   1,mm_arenas
        movei   1,4
        movem   1,mm_extent_capacity
        movei   1,1
        movem   1,mm_extent_count
        move    1,[010000,,0300000]
        movem   1,mm_extents
        move    1,[03,,3]           ; 8K physical kernel-dynamic extent
        movem   1,mm_extents+1

        movei   1,4
        movem   1,proc_high_slot
        move    1,[0200000000000]
        movem   1,__proc_descriptors+010
        move    1,[__uarea_v1316,,0400000]
        movem   1,__proc_descriptors+06
        move    1,[02000,,0]
        movem   1,__proc_descriptors+07
        movei   1,1
        movem   1,__uarea_v1316+0406
        movei   1,__records
        movem   1,proc_swap_records
        ; Validate the real packed DISK storage mode before swap-in.
        movei   1,2
        movei   2,1
        pushj   17,proc_storage_expect_v30
        jumpn   1,fail32_v1316
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
        move    1,backstore_blocks_used
        caie    1,010
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
        jrst    age_cooldown_v1313
        jrst    fail9_v1313

age_cooldown_v1313:
        ; Clock PI6's *production* timekeeping prefix decreases the
        ; retry delay. Do not clear it manually or use synthetic ticks.
        movei   010,077              ; 63 of 64 actual PI6 tick calls
tick_loop_v1313:
        pushj   17,proc_sched_pi_tick
        sojg    010,tick_loop_v1313
        move    1,proc_swap_pressure_ticks
        caie    1,1
        jrst    fail23_v1313
        move    1,proc_timer_clock
        caie    1,077
        jrst    fail24_v1313
        move    1,proc_sched_cursor
        caie    1,2                  ; no premature pending request
        jrst    fail25_v1313
        ; Exercise the unmodified production swap-pressure gate.
        ; The available resident process can run while swap-in waits.
        pushj   17,proc_select_rt_normal_swap_v879
        move    1,independent_run_v1316
        caie    1,1
        jrst    fail28_v1315
        move    1,proc_sched_cursor
        caie    1,2
        jrst    fail29_v1315

free_owner_v1313:
        ; Independently free the exact occupied extent through real MM.
        movei   1,0300000
        movei   2,3
        movei   3,3
        pushj   17,mm_free
        jumpn   1,fail10_v1313
        skipn   mm_extent_count
        jrst    retry_v1313
        jrst    fail11_v1313

retry_v1313:
        pushj   17,proc_sched_pi_tick
        skipn   proc_swap_pressure_ticks
        jrst    cooldown_expired_v1313
        jrst    fail26_v1313
cooldown_expired_v1313:
        move    1,proc_timer_clock
        caie    1,0100
        jrst    fail27_v1313
        ; The production selector, not the fixture, raises SWAP_REQUEST.
        pushj   17,proc_select_rt_normal_swap_v879
        move    1,proc_sched_cursor
        caie    1,0402
        jrst    fail30_v1315
        move    1,independent_run_v1316
        caie    1,1
        jrst    fail31_v1315
        pushj   17,proc_swap_mres_service_v481
        skipn   read_fault_v1316
        jrst    check_success_v1316
        camn    1,[-1]
        jrst    check_failed_read_v1317
        jrst    fail33_v1317
check_failed_read_v1317:
        ; Real MM rollback after an unsuccessful physical disk provider
        ; transfer must retain disk image ownership and release local VM.
        skipn   mm_extent_count
        jrst    check_failed_record_v1317
        jrst    fail34_v1317
check_failed_record_v1317:
        move    1,__records+2
        camn    1,[1,,010]
        jrst    check_failed_offset_v1317
        jrst    fail35_v1317
check_failed_offset_v1317:
        move    1,__uarea_v1316+0406
        caie    1,1
        jrst    fail36_v1317
        move    1,__storage_modes_v1316
        caie    1,020
        jrst    fail37_v1317
        move    1,backstore_blocks_used
        caie    1,010
        jrst    fail38_v1317
        move    1,proc_swap_blocks_used
        caie    1,010
        jrst    fail39_v1317
        move    1,__backing_bits_v1316
        caie    1,0776
        jrst    fail40_v1317
        move    1,__proc_descriptors+06
        trne    1,0200000             ; TRANSITION lock cleared
        jrst    fail41_v1317
        move    1,__proc_descriptors+07
        camn    1,[02000,,0]
        jrst    check_failed_event_v1317
        jrst    fail42_v1317
check_failed_event_v1317:
        move    1,event_calls_v1313
        caie    1,1                   ; fatal TERM path invoked once
        jrst    fail43_v1317
        move    1,read_calls_v1316
        caie    1,1
        jrst    fail44_v1317
        setz    1,
        popj    17,
check_success_v1316:
        caie    1,01002
        jrst    fail12_v1313
        move    1,proc_sched_cursor
        caie    1,01002
        jrst    fail13_v1313
        move    1,mm_extent_count
        caie    1,1
        jrst    fail14_v1313
        move    1,mm_extents
        camn    1,[02000,,0306000]
        jrst    check_owner_v1313
        jrst    fail15_v1313
check_owner_v1313:
        move    1,mm_extents+1
        camn    1,[01,,2]
        jrst    check_backing_v1313
        jrst    fail16_v1313
check_backing_v1313:
        move    1,__records+2
        caie    1,1
        jrst    fail17_v1313
        skipn   __uarea_v1316+0406
        jrst    check_counters_v1313
        jrst    fail17_v1313
check_counters_v1313:
        move    1,read_calls_v1316
        caie    1,1
        jrst    fail18_v1313
        skipn   backstore_blocks_used
        jrst    check_bitmap_v1316
        jrst    fail19_v1313
check_bitmap_v1316:
        skipn   proc_swap_blocks_used
        jrst    check_bitmap_bit_v1316
        jrst    fail19_v1313
check_bitmap_bit_v1316:
        skipn   __backing_bits_v1316
        jrst    check_storage_v1316
        jrst    fail19_v1313
check_storage_v1316:
        skipn   __storage_modes_v1316
        jrst    check_vm_v1316
        jrst    fail19_v1313
check_vm_v1316:
        move    1,__proc_descriptors+07
        camn    1,[02000,,0306000]
        jrst    check_payload_v1316
        jrst    fail19_v1313
check_payload_v1316:
        move    1,0306000
        camn    1,[012345670123]
        jrst    check_payload_end_v1316
        jrst    fail19_v1313
check_payload_end_v1316:
        move    1,0307777
        camn    1,[076543210765]
        jrst    check_fs_reclaim_v1316
        jrst    fail19_v1313
check_fs_reclaim_v1316:
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
fail23_v1313: movei 1,027
        popj 17,
fail24_v1313: movei 1,030
        popj 17,
fail25_v1313: movei 1,031
        popj 17,
fail26_v1313: movei 1,032
        popj 17,
fail27_v1313: movei 1,033
        popj 17,
fail28_v1315: movei 1,034
        popj 17,
fail29_v1315: movei 1,035
        popj 17,
fail30_v1315: movei 1,036
        popj 17,
fail31_v1315: movei 1,037
        popj 17,
fail32_v1316: movei 1,040
        popj 17,
fail33_v1317: movei 1,041
        popj 17,
fail34_v1317: movei 1,042
        popj 17,
fail35_v1317: movei 1,043
        popj 17,
fail36_v1317: movei 1,044
        popj 17,
fail37_v1317: movei 1,045
        popj 17,
fail38_v1317: movei 1,046
        popj 17,
fail39_v1317: movei 1,047
        popj 17,
fail40_v1317: movei 1,050
        popj 17,
fail41_v1317: movei 1,051
        popj 17,
fail42_v1317: movei 1,052
        popj 17,
fail43_v1317: movei 1,053
        popj 17,
fail44_v1317: movei 1,054
        popj 17,

; The original proc_swap_in is linked from production-v1316.s.
; The disk read provider is test-only, but writes the actual allocated
; physical image words; all validation, pin, storage and free paths
; are the unchanged production code.
        .globl backstore_read
backstore_read:
        aos     read_calls_v1316
        skipn   read_fault_v1316
        jrst    backstore_read_good_v1316
        seto    1,
        popj    17,
backstore_read_good_v1316:
        move    4,[012345670123]
        movem   4,(3)
        move    4,[076543210765]
        movem   4,01777(3)
        setz    1,
        popj    17,
        .globl proc_swap_reload_pure
proc_swap_reload_pure:
        seto    1,
        popj    17,
        .globl fs_zero_words
fs_zero_words:
        seto    1,
        popj    17,
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        halt    .

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
        .globl proc_timer_clock
proc_timer_clock: .word 0
        .globl proc_timer_next
proc_timer_next: .word 0
        .globl proc_swap_records
proc_swap_records: .word 0
        .globl proc_table
proc_table: .word __proc_descriptors
        .globl kconst_1_1
kconst_1_1: .word 1,,1
        .globl kconst_2_2
kconst_2_2: .word 2,,2
        .globl kconst_7_7
kconst_7_7: .word 7,,7
__records: .word 0
        .word 0
        .word 1,,010
        .word 0
__restored_base_v1313: .word 0
        .globl read_calls_v1316
read_calls_v1316: .word 0
        .globl read_fault_v1316
read_fault_v1316: .word 0
        .globl validation_fail_v1316
validation_fail_v1316: .word 0
        .globl free_calls_v1316
free_calls_v1316: .word 0
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
        .globl independent_run_v1316
independent_run_v1316: .word 0
        .globl backstore_bitmap
backstore_bitmap: .word __backing_bits_v1316
        .globl backstore_blocks
backstore_blocks: .word 020
        .globl backstore_blocks_used
backstore_blocks_used: .word 010
        .globl backstore_enabled
backstore_enabled: .word 1
        .globl proc_swap_blocks_used
proc_swap_blocks_used: .word 010
__backing_bits_v1316: .word 0776
        .globl proc_storage_runtime_v29
proc_storage_runtime_v29: .word __storage_modes_v1316
        .word 4
__storage_modes_v1316: .word 020
        .bss
__proc_descriptors: .block 014
__uarea_v1316: .block 0410
        .globl __test_exit
__test_exit: .block 1
