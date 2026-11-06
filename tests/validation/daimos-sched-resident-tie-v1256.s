; Native PDP-6 selector regression for resident-locality priority ties.
; A strictly higher-priority swapped process must still receive service.
        .text
        .globl main
main:
        ; First the real F07 condition: a resident requester (3) competes
        ; with a nonresident spinner (5) of identical score. Cursor 4
        ; favored 5 before the v1256 locality tie-breaker.
        pushj   17,select_v1256
        caie    1,3
        jrst    fail_old_v1256
        move    2,proc_sched_cursor
        caie    2,3
        jrst    fail_cursor_v1256

        ; A *strictly better* swapped candidate must not be starved.
        move    2,[0200023,,0]
        movem   2,__ptable+021
        pushj   17,select_v1256
        jumpe   1,check_high_v1256
        jrst    fail_priority_v1256
check_high_v1256:
        move    2,proc_sched_cursor
        caie    2,0405
        jrst    fail_priority_v1256

        ; Both resident: preserve the old cyclic tie-breaking policy.
        move    2,[0200024,,0]
        movem   2,__ptable+021
        move    2,[044000,,012000]
        movem   2,__ptable+020
        pushj   17,select_v1256
        caie    1,5
        jrst    fail_residents_v1256

        ; Both swapped: the same cyclic tie must still choose slot 5.
        move    2,[044000,,0]
        movem   2,__ptable+012
        movem   2,__ptable+020
        pushj   17,select_v1256
        jumpe   1,check_both_swap_v1256
        jrst    fail_disk_v1256
check_both_swap_v1256:
        move    2,proc_sched_cursor
        caie    2,0405
        jrst    fail_disk_v1256

        ; A fatal-cleanup executive continuation with VM=0 must not
        ; acquire the ordinary disk-candidate locality penalty.
        move    2,[044000,,012000]
        movem   2,__ptable+012
        movei   2,4
        movem   2,__uarea5+024
        pushj   17,select_v1256
        caie    1,5
        jrst    fail_fatal_v1256
        setz    1,
        popj    17,

select_v1256:
        movei   2,4
        movem   2,proc_sched_cursor
        setzm   proc_sched_deferred_ticks
        pushj   17,proc_sched_resched_select
        popj    17,

fail_old_v1256:
        movei   1,1
        popj    17,
fail_cursor_v1256:
        movei   1,2
        popj    17,
fail_priority_v1256:
        movei   1,3
        popj    17,
fail_residents_v1256:
        movei   1,4
        popj    17,
fail_disk_v1256:
        movei   1,5
        popj    17,
fail_fatal_v1256:
        movei   1,6
        popj    17,

        .data
        .globl kconst_7_7
kconst_7_7: .word 7,,7
        .globl proc_sched_deferred_ticks
proc_sched_deferred_ticks: .word 0
        .globl proc_sched_age_phase
proc_sched_age_phase: .word 0
        .globl proc_finish_last_tick_v881
proc_finish_last_tick_v881: .word 0
        .globl proc_timer_clock
proc_timer_clock: .word 0
        .globl proc_current_slot
proc_current_slot: .word 0
        .globl proc_rt_owner
proc_rt_owner: .word 0
        .globl proc_sched_cursor
proc_sched_cursor: .word 4
        .globl proc_runq_head
proc_runq_head: .word 3
        .globl proc_swap_pressure_ticks
proc_swap_pressure_ticks: .word 0
        .globl proc_swap_records
proc_swap_records: .word __swap_records
__swap_records: .block 5
        .word 000400,,01000
        .globl proc_high_slot
proc_high_slot: .word 6
        .globl proc_table
proc_table: .word __ptable
__ptable:
        .block 011                  ; slots 0, 1, 2
        .word __uarea3,,0400000    ; slot 3 meta
        .word 044000,,010000       ; slot 3 VM resident
        .word 0200024,,5           ; slot 3 RUN, next=5
        .block 3                    ; slot 4
        .word __uarea5,,0400000    ; slot 5 meta
        .word 044000,,0            ; slot 5 VM disk-backed
        .word 0200024,,0           ; slot 5 RUN, end queue
__uarea3: .block 0410
__uarea5: .block 0410

        .bss
        .globl __test_exit
__test_exit: .block 1
