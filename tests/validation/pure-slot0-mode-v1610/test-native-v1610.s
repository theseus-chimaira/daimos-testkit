; Execute the actual source-linked MRES service with real two-bit
; process storage mode operations. Only disk I/O, exchange and event
; operations are controlled: no MM or disk payload is changed here.
        .text
        .globl main
        .globl __test_exit
        .globl proc_swap_mres_service_v481
        .globl proc_storage_expect_v30
        .globl proc_swap_in
        .globl proc_swap_exchange_pair_v826
        .globl proc_swap_exchange_execute_v832
        .globl proc_event_apply

main:
        ; One runnable, inactive process at slot 1.
        movei   1,proc_table_v1610
        movem   1,proc_table
        movei   1,proc_records_v1610
        movem   1,proc_swap_records
        movei   1,3
        movem   1,proc_high_slot
        movei   1,proc_modes_v1610
        movem   1,proc_storage_runtime_v29
        movei   1,3
        movem   1,proc_storage_runtime_v29+1
        move    1,[0200000000000]
        movem   1,proc_table_v1610+5
        move    1,[02000,,0]
        movem   1,proc_table_v1610+4
        movei   1,012345
        movem   1,proc_records_v1610+1

        ; PACKED mode = 2 at slot 1, not a disk run.
        movei   1,010
        movem   1,proc_modes_v1610
        movei   1,0401
        movem   1,proc_sched_cursor
        pushj   17,proc_swap_mres_service_v481
        jumpn   1,fail1_v1610
        move    1,proc_sched_cursor
        caie    1,1
        jrst    fail2_v1610
        move    1,proc_swap_pressure_ticks
        caie    1,0100
        jrst    fail3_v1610
        skipn   disk_calls_v1610
        jrst    check_packed_other_v1610
        jrst    fail4_v1610
check_packed_other_v1610:
        skipn   event_calls_v1610
        jrst    check_packed_record_v1610
        jrst    fail5_v1610
check_packed_record_v1610:
        move    1,proc_records_v1610+1
        caie    1,012345
        jrst    fail6_v1610
        movei   1,1
        movei   2,2
        pushj   17,proc_storage_expect_v30
        jumpn   1,fail7_v1610

        ; DISK state must keep the original swap-in and READY_ONCE.
        movei   1,4
        movem   1,proc_modes_v1610
        setzm   proc_swap_pressure_ticks
        movei   1,0401
        movem   1,proc_sched_cursor
        pushj   17,proc_swap_mres_service_v481
        caie    1,01001
        jrst    fail10_v1610
        move    1,proc_sched_cursor
        caie    1,01001
        jrst    fail11_v1610
        move    1,disk_calls_v1610
        caie    1,1
        jrst    fail12_v1610
        skipn   event_calls_v1610
        jrst    check_invalid_v1610
        jrst    fail13_v1610

check_invalid_v1610:
        ; Impossible state=3 must not reach disk or a fatal event.
        movei   1,014
        movem   1,proc_modes_v1610
        movei   1,0401
        movem   1,proc_sched_cursor
        pushj   17,proc_swap_mres_service_v481
        jumpn   1,fail14_v1610
        move    1,proc_sched_cursor
        caie    1,1
        jrst    fail15_v1610
        move    1,disk_calls_v1610
        caie    1,1
        jrst    fail16_v1610
        skipn   event_calls_v1610
        jrst    success_v1610
        jrst    fail17_v1610
success_v1610:
        setz    1,
        popj    17,

fail1_v1610: movei 1,1
        popj 17,
fail2_v1610: movei 1,2
        popj 17,
fail3_v1610: movei 1,3
        popj 17,
fail4_v1610: movei 1,4
        popj 17,
fail5_v1610: movei 1,5
        popj 17,
fail6_v1610: movei 1,6
        popj 17,
fail7_v1610: movei 1,7
        popj 17,
fail10_v1610: movei 1,010
        popj 17,
fail11_v1610: movei 1,011
        popj 17,
fail12_v1610: movei 1,012
        popj 17,
fail13_v1610: movei 1,013
        popj 17,
fail14_v1610: movei 1,014
        popj 17,
fail15_v1610: movei 1,015
        popj 17,
fail16_v1610: movei 1,016
        popj 17,
fail17_v1610: movei 1,017
        popj 17,

proc_swap_in:
        aos     disk_calls_v1610
        setz    1,
        popj    17,
proc_swap_exchange_pair_v826:
        seto    1,
        popj    17,
proc_swap_exchange_execute_v832:
        seto    1,
        popj    17,
proc_event_apply:
        aos     event_calls_v1610
        setz    1,
        popj    17,

        .bss
__test_exit: .block 1
        .globl proc_sched_cursor
proc_sched_cursor: .block 1
        .globl proc_swap_pressure_ticks
proc_swap_pressure_ticks: .block 1
        .globl proc_high_slot
proc_high_slot: .block 1
        .globl proc_table
proc_table: .block 1
        .globl proc_swap_records
proc_swap_records: .block 1
        .globl proc_storage_runtime_v29
proc_storage_runtime_v29: .block 2
        .globl proc_timer_clock
proc_timer_clock: .block 1
disk_calls_v1610: .block 1
event_calls_v1610: .block 1
proc_table_v1610: .block 011
proc_records_v1610: .block 3
proc_modes_v1610: .block 1
