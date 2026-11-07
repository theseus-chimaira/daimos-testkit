; Exercise the production slot-0 swap service with no viable exchange pair.
; Stubs control only allocator and exchange outcomes, not service branches.
        .text
        .globl main
main:
        movei 1,1
        movem 1,__stage
        movei 1,4
        movem 1,proc_high_slot
        move 1,__run_state
        movem 1,__proc_descriptors+010 ; slot 2, descriptor word 2
        movei 1,__records
        movem 1,proc_swap_records
        movei 1,0402                 ; swapped slot 2 requested
        movem 1,proc_sched_cursor
        movei 1,1                    ; allocator returns PRESSURE
        movem 1,__swap_result
        pushj 17,proc_swap_mres_service_v481
        movem 1,__service_rc
        move 1,proc_sched_cursor
        movem 1,__post_cursor
        move 1,__proc_descriptors+010
        movem 1,__post_state
        move 1,__records+2
        movem 1,__post_backing
        move 1,__service_rc
        jumpn 1,__fail
        move 1,proc_swap_pressure_ticks
        caie 1,0100
        jrst __fail
        move 1,proc_sched_cursor
        caie 1,2                     ; request consumed, slot retained
        jrst __fail
        move 1,__in_calls
        caie 1,1
        jrst __fail
        move 1,__pair_calls
        caie 1,3                     ; all slots scanned
        jrst __fail
        skipn __records+2            ; backing remains owned
        jrst __fail
        skipn __proc_descriptors+010 ; RUN state remains published
        jrst __fail
        skipn __event_calls
        jrst __after_no_event
        jrst __fail
__after_no_event:
        movei 1,2
        movem 1,__stage
        pushj 17,proc_swap_mres_service_v481
        jumpn 1,__fail               ; consumed request is not retried
        move 1,__in_calls
        caie 1,1
        jrst __fail

        ; Fatal return, unlike pressure, reports TERM for the owner.
        setzm proc_swap_pressure_ticks
        movei 1,3
        movem 1,__stage
        movei 1,0402
        movem 1,proc_sched_cursor
        setom __swap_result
        pushj 17,proc_swap_mres_service_v481
        camn 1,[-1]
        jrst __fatal_done
        jrst __fail
__fatal_done:
        move 1,__event_calls
        caie 1,1
        jrst __fail
        move 1,__event_slot
        caie 1,2
        jrst __fail
        move 1,__event_type
        caie 1,1
        jrst __fail
        skipn proc_swap_pressure_ticks
        jrst __success_setup
        jrst __fail

__success_setup:
        movei 1,4
        movem 1,__stage
        ; Successful restoration grants one dispatch opportunity.
        movei 1,0402
        movem 1,proc_sched_cursor
        setzm __swap_result
        pushj 17,proc_swap_mres_service_v481
        caie 1,01002                 ; success returns dispatch cursor
        jrst __fail
        move 1,proc_sched_cursor
        caie 1,01002
        jrst __fail
        move 1,__event_calls
        caie 1,1
        jrst __fail
        move 1,__in_calls
        caie 1,3
        jrst __fail
        setz 1,
        popj 17,
__fail:
        move 1,__stage
        popj 17,

        .globl proc_swap_in
proc_swap_in:
        aos __in_calls
        move 1,__swap_result
        popj 17,
        .globl proc_swap_exchange_pair_v826
proc_swap_exchange_pair_v826:
        aos __pair_calls
        seto 1,                     ; intentionally no viable partner
        popj 17,
        .globl proc_swap_exchange_execute_v832
proc_swap_exchange_execute_v832:
        aos __exchange_calls
        seto 1,
        popj 17,
        .globl proc_event_apply
proc_event_apply:
        aos __event_calls
        movem 1,__event_slot
        movem 2,__event_type
        setz 1,
        popj 17,
        .globl kret_zero
kret_zero:
        setz 1,
        popj 17,
        .globl kret_neg1
kret_neg1:
        seto 1,
        popj 17,

        .data
        .globl proc_sched_cursor
proc_sched_cursor: .word 0
        .globl proc_high_slot
proc_high_slot: .word 0
        .globl proc_swap_pressure_ticks
proc_swap_pressure_ticks: .word 0
        .globl proc_swap_records
proc_swap_records: .word 0
        .globl proc_table
proc_table: .word __proc_descriptors
        .globl kconst_1_1
kconst_1_1: .word 1,,1
__run_state: .word 0200000000000  ; leading zero requests octal
__records: .word 0
           .word 0
           .word 012345
           .word 0
__swap_result: .word 0
        .globl __in_calls
__in_calls: .word 0
        .globl __pair_calls
__pair_calls: .word 0
        .globl __exchange_calls
__exchange_calls: .word 0
        .globl __event_calls
__event_calls: .word 0
__event_slot: .word 0
__event_type: .word 0
        .globl __service_rc
__service_rc: .word 0
        .globl __post_cursor
__post_cursor: .word 0
        .globl __post_state
__post_state: .word 0
        .globl __post_backing
__post_backing: .word 0
        .globl __stage
__stage: .word 0
        .bss
__proc_descriptors: .block 014
        .globl __test_exit
__test_exit: .block 1
