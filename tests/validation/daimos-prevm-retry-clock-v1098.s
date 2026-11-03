; PDP-6 v1098: a prepublished EXIT finalizer must arm its first retry.
; The fatal private-stack handoff deliberately publishes FINALIZE+PREVM
; before slot-0 teardown; that marker is NOT the retry-clock pending bit.
        .text
        .globl main
        .globl proc_finish_mark_pending_v892
        .globl proc_finish_last_tick_v881
        .globl proc_timer_clock

main:
        movei   17,__stack-1
        hrli    17,-0400
        move    0,[0500000,,0333]
        movem   0,__uarea+067
        setzm   proc_finish_last_tick_v881
        movei   0,02345
        movem   0,proc_timer_clock
        movei   3,__uarea
        move    4,__uarea+067
        pushj   17,proc_finish_mark_pending_v892
        move    0,proc_finish_last_tick_v881
        camn    0,[0400020,,02345]
        jrst    v1098_first_clock
        jrst    v1098_fail1
v1098_first_clock:
        move    0,__uarea+067
        camn    0,[0500000,,0333]
        jrst    v1098_keep_backoff
        jrst    v1098_fail2

v1098_keep_backoff:
        ; A previously failing owner retains its existing backoff.
        move    0,[0400100,,02000]
        movem   0,proc_finish_last_tick_v881
        movei   0,04000
        movem   0,proc_timer_clock
        movei   3,__uarea
        move    4,__uarea+067
        pushj   17,proc_finish_mark_pending_v892
        move    0,proc_finish_last_tick_v881
        camn    0,[0400100,,02000]
        jrst    v1098_new_owner
        jrst    v1098_fail3

v1098_new_owner:
        ; An entirely new finalizer resets an older shared backoff.
        move    0,[0401000,,0123]
        movem   0,proc_finish_last_tick_v881
        setzm   __uarea+067
        movei   0,010000
        movem   0,proc_timer_clock
        movei   3,__uarea
        move    4,[0400000,,012345]
        pushj   17,proc_finish_mark_pending_v892
        move    0,proc_finish_last_tick_v881
        camn    0,[0400020,,010000]
        jrst    v1098_new_owner_marker
        jrst    v1098_fail4
v1098_new_owner_marker:
        move    0,__uarea+067
        camn    0,[0400000,,012345]
        jrst    v1098_stale_epoch
        jrst    v1098_fail5

v1098_stale_epoch:
        ; A PREVM marker may exist even though no timer is armed.
        ; The previous shared delay/epoch must not be reused.
        move    0,[01000,,0123]
        movem   0,proc_finish_last_tick_v881
        move    0,[0500000,,012345]
        movem   0,__uarea+067
        movei   0,07000
        movem   0,proc_timer_clock
        movei   3,__uarea
        move    4,__uarea+067
        pushj   17,proc_finish_mark_pending_v892
        move    0,proc_finish_last_tick_v881
        camn    0,[0400020,,07000]
        jrst    v1098_ok
        jrst    v1098_fail6

v1098_ok:
        setz    1,
        jrst    v1098_done
v1098_fail1:
        movei   1,1
        jrst    v1098_done
v1098_fail2:
        movei   1,2
        jrst    v1098_done
v1098_fail3:
        movei   1,3
        jrst    v1098_done
v1098_fail4:
        movei   1,4
        jrst    v1098_done
v1098_fail5:
        movei   1,5
        jrst    v1098_done
v1098_fail6:
        movei   1,6
v1098_done:
        movem   1,__test_exit
        jrst    4,0

        .data
proc_finish_last_tick_v881: .word 0
proc_timer_clock: .word 0
__uarea: .block 0100
        .bss
__stack: .block 0400
        .globl __test_exit
__test_exit: .block 1
