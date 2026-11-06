; Native PDP-6 F07: software PI6 must service a due sleep timer before
; it selects a runnable process. All words and opcodes are octal.
        .equ PROC_TIMER_DUE_LH,0200000
        .text
        .globl main
main:
        movei   1,process_words_v1252
        movem   1,proc_table
        movei   1,2
        movem   1,proc_high_slot
        setzm   proc_runq_head
        setzm   resched_calls_v1252
        setzm   timer_due_at_select_v1252
        move    1,[0200000,,0100]
        movem   1,proc_timer_next
        movei   1,0102
        movem   1,proc_timer_clock
        move    1,[0320000,,0400100]
        movem   1,process_words_v1252+5

        pushj   17,proc_sched_resched_choose

        move    1,process_words_v1252+5
        camn    1,[0200000,,0]
        jrst    check_runq_v1252
        movei   1,011                ; old code leaves sleeper blocked
        popj    17,
check_runq_v1252:
        move    1,proc_runq_head
        caie    1,1
        jrst    fail_runq_v1252
        skipn   proc_timer_next
        jrst    check_schedule_v1252
        movei   1,013
        popj    17,
check_schedule_v1252:
        skipn   timer_due_at_select_v1252
        jrst    check_schedule_count_v1252
        movei   1,017
        popj    17,
check_schedule_count_v1252:
        move    1,resched_calls_v1252
        caie    1,1
        jrst    fail_schedule_v1252
        ; Without DUE, the software PI6 path must not wake the sleeper.
        ; It should still perform the ordinary scheduler selection.
        setzm   proc_runq_head
        move    1,[0320000,,0400100]
        movem   1,process_words_v1252+5
        move    1,[0400000,,0100]
        movem   1,proc_timer_next
        pushj   17,proc_sched_resched_choose
        move    1,process_words_v1252+5
        camn    1,[0320000,,0400100]
        jrst    check_not_due_v1252
        movei   1,015
        popj    17,
check_not_due_v1252:
        move    1,proc_timer_next
        camn    1,[0400000,,0100]
        jrst    check_second_schedule_v1252
        movei   1,016
        popj    17,
check_second_schedule_v1252:
        move    1,resched_calls_v1252
        caie    1,2
        jrst    fail_schedule_v1252
        setz    1,
        popj    17,
fail_runq_v1252:
        movei   1,012
        popj    17,
fail_schedule_v1252:
        movei   1,014
        popj    17,

; Isolate the actual production transition. These two target labels
; simply return to main rather than performing an APR context switch.
        .globl proc_sched_resched_select
proc_sched_resched_select:
        aos     resched_calls_v1252
        move    0,proc_timer_next
        tlne    0,PROC_TIMER_DUE_LH
        setom   timer_due_at_select_v1252
        setz    1,
        popj    17,
        .globl proc_sched_restore_selected
proc_sched_restore_selected:
        popj    17,

        .bss
        .globl __test_exit
__test_exit: .block 1
        .globl proc_table
proc_table: .block 1
        .globl proc_high_slot
proc_high_slot: .block 1
        .globl proc_runq_head
proc_runq_head: .block 1
        .globl proc_timer_clock
proc_timer_clock: .block 1
        .globl proc_timer_next
proc_timer_next: .block 1
resched_calls_v1252: .block 1
timer_due_at_select_v1252: .block 1
process_words_v1252: .block 6
