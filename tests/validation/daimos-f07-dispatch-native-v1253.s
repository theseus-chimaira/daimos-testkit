; Execute the v1253 diagnostic hook bodies on the PDP-6, not a reimplementation.
; The shell extracts them verbatim from an instrumented disposable source.
        .text
        .globl main
main:
        movei   1,3
        pushj   17,proc_sched_restore_selected
        movei   1,5
        pushj   17,proc_sched_restore_selected
        movei   1,3
        pushj   17,proc_sched_restore_selected
        setz    1,
        pushj   17,proc_sched_restore_selected

        move    2,daimos_f07u_dispatch_v1253+3
        caie    2,2
        jrst    fail_dispatch3_v1253
        move    2,daimos_f07u_dispatch_v1253+5
        caie    2,1
        jrst    fail_dispatch5_v1253
        move    2,daimos_f07u_idle_count_v1253
        caie    2,1
        jrst    fail_idle_v1253
        skipn   proc_current_slot
        jrst    check_swap_v1253
        jrst    fail_current_v1253

check_swap_v1253:
        movei   2,3
        movem   2,proc_sched_cursor
        pushj   17,proc_select_done_swap_v879
        movei   2,5
        movem   2,proc_sched_cursor
        pushj   17,proc_select_done_swap_v879
        movei   2,3
        movem   2,proc_sched_cursor
        pushj   17,proc_select_done_swap_v879

        move    2,daimos_f07u_swapreq_v1253+3
        caie    2,2
        jrst    fail_swap3_v1253
        move    2,daimos_f07u_swapreq_v1253+5
        caie    2,1
        jrst    fail_swap5_v1253
        move    2,proc_sched_cursor
        caie    2,0403
        jrst    fail_cursor_v1253
        setz    1,
        popj    17,

fail_dispatch3_v1253:
        movei   1,1
        popj    17,
fail_dispatch5_v1253:
        movei   1,2
        popj    17,
fail_idle_v1253:
        movei   1,3
        popj    17,
fail_current_v1253:
        movei   1,4
        popj    17,
fail_swap3_v1253:
        movei   1,5
        popj    17,
fail_swap5_v1253:
        movei   1,6
        popj    17,
fail_cursor_v1253:
        movei   1,7
        popj    17,

        .bss
        .globl __test_exit
__test_exit: .block 1
        .globl proc_current_slot
proc_current_slot: .block 1
        .globl proc_sched_cursor
proc_sched_cursor: .block 1
