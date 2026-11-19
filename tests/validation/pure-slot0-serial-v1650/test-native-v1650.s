; Exact original PDP-6 slot-0 PI6 interrupted-PC and swap-owner gate.
; The extracted scheduler leaf calls only our counting continuation.
; This is a native instruction test, not a simulated C predicate.
        .text
        .globl main
        .globl proc_idle_loop
        .globl proc_idle_loop_end
        .globl pdp10_pi_level6
        .globl proc_timer_next
        .globl proc_sched_cursor
        .globl proc_sched_select
        .globl proc_sched_tick_ready
main:
        movei   10,cases_v1650
        movei   11,case_count_v1650
case_next_v1650:
        move    1,(10)
        movem   1,pdp10_pi_level6
        move    1,1(10)
        movem   1,proc_timer_next
        move    1,2(10)
        movem   1,proc_sched_cursor
        setzm   switch_count_v1650
        pushj   17,proc_sched_tick_idle_check
        move    1,switch_count_v1650
        came    1,3(10)
        jrst    case_bad_v1650
        addi    10,4
        sojg    11,case_next_v1650
        setz    1,
        popj    17,
case_bad_v1650:
        move    1,11
        popj    17,

; No fake scheduler check: only the final branch destinations are stubs.
proc_sched_select:
        aos     switch_count_v1650
        popj    17,

; This is the caller-boundary interval recognized by the *original*
; PI6 instruction test. Actual v1643 FULL MRES 035252 is far outside.
proc_idle_loop:
        .block 020
proc_idle_loop_end:
        .word 0

        .data
        .globl proc_timer_next
proc_timer_next: .word 0
        .globl proc_sched_cursor
proc_sched_cursor: .word 0
        .globl pdp10_pi_level6
pdp10_pi_level6: .word 0
        .globl switch_count_v1650
switch_count_v1650: .word 0

        ; PC, timer frontier, swap request, expected selections
        .equ case_count_v1650,11
cases_v1650:
        .word proc_idle_loop-1
        .word 0200000,,0
        .word 0400
        .word 0
        .word proc_idle_loop
        .word 0200000,,0
        .word 0400
        .word 1
        .word proc_idle_loop
        .word 0
        .word 0400
        .word 0
        .word proc_idle_loop_end-1
        .word 0
        .word 0400
        .word 0
        .word proc_idle_loop_end
        .word 0200000,,0
        .word 0400
        .word 0
        .word 035252
        .word 0200000,,0
        .word 0400
        .word 0
        .word 035252
        .word 0
        .word 0400
        .word 0
        ; A runnable slot-0 idle with no swap request may switch.
        .word proc_idle_loop
        .word 0
        .word 1
        .word 1
        ; An already-due timer may schedule even with cursor==0.
        .word proc_idle_loop+1
        .word 0200000,,0
        .word 0
        .word 1
        ; Merely clearing the swap cursor cannot enable a kernel MRES PC.
        .word 035252
        .word 0
        .word 1
        .word 0
        .word 035252
        .word 0200000,,0
        .word 1
        .word 0
        .bss
        .globl __test_exit
__test_exit: .block 1
