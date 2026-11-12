; Exercise the actual slot-0 swap service around a refused bitmap release.
; The v1405 transaction/MM/bitmap stubs are included by the test runner.
; A returned failure must send TERM, not publish a RESIDENT VM or READY_ONCE.
        .text
        .globl main
main:
        movei   17,__stack-1
        hrli    17,-0400
        movei   1,1
        movem   1,__uarea+0406
        movei   1,4
        movem   1,proc_high_slot
        movei   1,0402
        movem   1,proc_sched_cursor
        pushj   17,proc_swap_mres_service_v481
        camn    1,[-1]
        jrst    check_term_v1493
        jrst    fail_v1493
check_term_v1493:
        move    1,event_calls_v1493
        caie    1,1
        jrst    fail_v1493
        move    1,event_slot_v1493
        caie    1,2
        jrst    fail_v1493
        move    1,event_kind_v1493
        caie    1,1
        jrst    fail_v1493
        move    1,proc_sched_cursor
        caie    1,2
        jrst    fail_v1493
        skipn   __publish_calls_v1405
        jrst    check_owner_v1493
        jrst    fail_v1493
check_owner_v1493:
        move    1,__rollback_calls_v1405
        caie    1,1
        jrst    fail_v1493
        move    1,__record+2
        came    1,[1,,010]
        jrst    fail_v1493
        move    1,__descriptor+7
        came    1,[02000,,0]
        jrst    fail_v1493
        move    1,__descriptor+6
        trne    1,0200000
        jrst    fail_v1493
        move    1,backstore_blocks_used
        caie    1,010
        jrst    fail_v1493
        move    1,proc_swap_blocks_used
        caie    1,010
        jrst    fail_v1493
        move    1,__bitmap_v1405
        caie    1,0376
        jrst    fail_v1493
        move    1,__read_calls_v1405
        caie    1,1
        jrst    fail_v1493
        skipn   __invariant_calls_v1405
        jrst    pass_v1493
fail_v1493:
        movei   1,1
        jrst    finish_v1493
pass_v1493:
        setz    1,
finish_v1493:
        movem   1,__test_exit
        jrst    4,0

        .globl proc_event_apply
proc_event_apply:
        aos     event_calls_v1493
        movem   1,event_slot_v1493
        movem   2,event_kind_v1493
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

; The fixture must not enter the allocator-pressure exchange policy:
; free refusal is a negative transaction error, not MM_ERR_NOMEM.
        .globl proc_swap_exchange_pair_v826
proc_swap_exchange_pair_v826:
        aos     unexpected_exchange_v1493
        seto    1,
        popj    17,
        .globl proc_swap_exchange_execute_v832
proc_swap_exchange_execute_v832:
        aos     unexpected_exchange_v1493
        seto    1,
        popj    17,

        .data
        .globl proc_high_slot
proc_high_slot: .word 0
        .globl proc_sched_cursor
proc_sched_cursor: .word 0
        .globl proc_swap_pressure_ticks
proc_swap_pressure_ticks: .word 0
        .globl proc_timer_clock
proc_timer_clock: .word 0
        .globl event_calls_v1493
event_calls_v1493: .word 0
        .globl event_slot_v1493
event_slot_v1493: .word 0
        .globl event_kind_v1493
event_kind_v1493: .word 0
        .globl unexpected_exchange_v1493
unexpected_exchange_v1493: .word 0
