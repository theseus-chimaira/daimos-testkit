; Native PDP-6 diagnostic: repeated permanently invalid bitmap release.
; The loop supplies repeated requests (it does not model scheduler timing).
; Real proc_swap_in, checked backstore_free and slot-0 swap service are linked.
        .text
        .globl main
main:
        movei   17,__stack-1
        hrli    17,-0400
        movei   1,1
        movem   1,__uarea+0406
        movei   1,4
        movem   1,proc_high_slot

again_v1505:
        movei   1,0402               ; real slot-0 swap-in request
        movem   1,proc_sched_cursor
        pushj   17,proc_swap_mres_service_v481
        camn    1,[-1]
        jrst    refused_v1505
        jrst    fail_v1505
refused_v1505:
        aos     attempt_count_v1505
        move    1,proc_sched_cursor
        caie    1,2                  ; no false READY_ONCE
        jrst    fail_v1505
        move    1,__descriptor+7
        came    1,[02000,,0]
        jrst    fail_v1505
        move    1,__descriptor+6
        trne    1,0200000            ; TRANSITION must be undone
        jrst    fail_v1505
        move    1,__record+2
        came    1,[1,,010]          ; original DISK run retained
        jrst    fail_v1505
        move    1,__bitmap_v1405
        caie    1,0376              ; still corrupt, no silent repair
        jrst    fail_v1505
        move    1,backstore_blocks_used
        caie    1,010
        jrst    fail_v1505
        move    1,proc_swap_blocks_used
        caie    1,010
        jrst    fail_v1505
        skipn   __pins_v1405
        jrst    pins_ok_v1505
        jrst    fail_v1505
pins_ok_v1505:
        move    1,attempt_count_v1505
        caige   1,6
        jrst    again_v1505
        movei   1,1
        movem   1,stage_v1505

        ; Even after six repeated requests, no DISK owner was discarded.
        move    1,event_calls_v1505
        caie    1,6
        jrst    fail_v1505
        move    1,__rollback_calls_v1405
        caie    1,6
        jrst    fail_v1505
        move    1,__read_calls_v1405
        caie    1,6
        jrst    fail_v1505
        skipn   __publish_calls_v1405
        jrst    repair_v1505
        jrst    fail_v1505

repair_v1505:
        movei   1,2
        movem   1,stage_v1505
        ; Explicitly repair the missing allocation bit (fixture only).
        ; The next real checked transaction may then restore exactly once.
        movei   1,0776
        movem   1,__bitmap_v1405
        movei   1,0402
        movem   1,proc_sched_cursor
        pushj   17,proc_swap_mres_service_v481
        movem   1,repair_return_v1505
        caie    1,01002              ; READY_ONCE | selected slot
        jrst    fail_v1505
        jrst    success_v1505
success_v1505:
        movei   1,3
        movem   1,stage_v1505
        move    1,proc_sched_cursor
        caie    1,01002             ; exact READY_ONCE after success
        jrst    fail_v1505
        move    1,__publish_calls_v1405
        caie    1,1
        jrst    fail_v1505
        move    1,event_calls_v1505
        caie    1,6
        jrst    fail_v1505
        move    1,__rollback_calls_v1405
        caie    1,6
        jrst    fail_v1505
        move    1,__read_calls_v1405
        caie    1,7
        jrst    fail_v1505
        skipn   __bitmap_v1405
        jrst    check_blocks_v1505
        jrst    fail_v1505
check_blocks_v1505:
        movei   1,4
        movem   1,stage_v1505
        skipn   proc_swap_blocks_used
        jrst    check_backstore_v1505
        jrst    fail_v1505
check_backstore_v1505:
        skipn   backstore_blocks_used
        jrst    check_mode_v1505
        jrst    fail_v1505
check_mode_v1505:
        movei   1,5
        movem   1,stage_v1505
        skipn   __mode_v1405
        jrst    check_errors_v1505
        jrst    fail_v1505
check_errors_v1505:
        movei   1,6
        movem   1,stage_v1505
        skipn   __invariant_calls_v1405
        jrst    pass_v1505
        jrst    fail_v1505
pass_v1505:
        setz    1,
        jrst    done_v1505
fail_v1505:
        move    1,stage_v1505
done_v1505:
        movem   1,__test_exit
        jrst    4,0

        .globl proc_event_apply
proc_event_apply:
        aos     event_calls_v1505
        movem   1,event_slot_v1505
        movem   2,event_kind_v1505
        setz    1,
        popj    17,
        .globl kret_zero
kret_zero:
        setz    1,
        popj    17,
        .globl kret_neg1
kret_neg1:
        seto    1,
        popj    17,
        .globl proc_swap_exchange_pair_v826
proc_swap_exchange_pair_v826:
        aos     unexpected_exchange_v1505
        seto    1,
        popj    17,
        .globl proc_swap_exchange_execute_v832
proc_swap_exchange_execute_v832:
        aos     unexpected_exchange_v1505
        seto    1,
        popj    17,

        .data
        .globl proc_high_slot
proc_high_slot: .word 0
        .globl proc_sched_cursor
proc_sched_cursor: .word 0
        .globl proc_swap_pressure_ticks
proc_swap_pressure_ticks: .word 0
        .globl attempt_count_v1505
attempt_count_v1505: .word 0
stage_v1505: .word 010
        .globl repair_return_v1505
repair_return_v1505: .word 0
        .globl event_calls_v1505
event_calls_v1505: .word 0
        .globl event_slot_v1505
event_slot_v1505: .word 0
        .globl event_kind_v1505
event_kind_v1505: .word 0
        .globl unexpected_exchange_v1505
unexpected_exchange_v1505: .word 0
