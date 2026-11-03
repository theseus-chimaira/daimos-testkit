; PDP-6 real NEWSESSION and final-TTY release contract.
; A busy TTY must not strand its session when the last member leaves.
        .text
        .globl main
main:
        movei   17,__stack-1
        hrli    17,-0400
        ; With a pinned canonical line, no process/session/TTY field
        ; may change. This check also rejects the pre-v1082 source.
        movei   1,1
        movem   1,__blocked
        movem   1,__line_live
        movei   2,0
        movei   3,3
        movei   4,__proc
        pushj   17,proc_control_newsession
        movem   1,__first_return_v1082
        camn    1,[-1]
        jrst    check_refusal_v1082
        jrst    fail_1_v1082
check_refusal_v1082:
        move    1,__proc
        camn    1,[__uarea,,5]
        jrst    check_old_ctl_v1082
        jrst    fail_2_v1082
check_old_ctl_v1082:
        move    1,__uarea+024
        camn    1,[020000000050]
        jrst    check_old_tty_v1082
        jrst    fail_3_v1082
check_old_tty_v1082:
        move    1,proc_tty_records
        camn    1,[040000000005]
        jrst    check_live_v1082
        jrst    fail_4_v1082
check_live_v1082:
        skipn   __line_live
        jrst    fail_5_v1082
        move    1,__reset_calls
        caie    1,1
        jrst    fail_6_v1082
        move    1,__scan_error
        jumpn   1,fail_7_v1082
        ; The same process can retry and transition after MM unpins.
        setzm   __blocked
        movei   2,0
        movei   3,3
        movei   4,__proc
        pushj   17,proc_control_newsession
        caie    1,3
        jrst    fail_8_v1082
        move    1,__proc
        hrrz    1,1
        caie    1,3
        jrst    fail_9_v1082
        move    1,__uarea+024
        camn    1,[030]
        jrst    verify_lease_v1082
        jrst    fail_10_v1082
verify_lease_v1082:
        move    1,proc_tty_records
        camn    1,[040000000000]
        jrst    verify_clear_v1082
        jrst    fail_11_v1082
verify_clear_v1082:
        skipn   __line_live
        jrst    check_second_count_v1082
        jrst    fail_12_v1082
check_second_count_v1082:
        move    1,__reset_calls
        caie    1,2
        jrst    fail_13_v1082
        ; When other old-session members remain, their TTY is not
        ; ours to release. NEWSESSION still commits this caller.
        movei   1,1
        movem   1,__peer_present
        movem   1,__line_live
        move    1,[__uarea,,5]
        movem   1,__proc
        move    1,[020000000050]
        movem   1,__uarea+024
        move    1,[040000000005]
        movem   1,proc_tty_records
        movei   2,0
        movei   3,3
        movei   4,__proc
        pushj   17,proc_control_newsession
        caie    1,3
        jrst    fail_14_v1082
        move    1,proc_tty_records
        camn    1,[040000000005]
        jrst    verify_peer_v1082
        jrst    fail_15_v1082
verify_peer_v1082:
        skipn   __line_live
        jrst    fail_16_v1082
        move    1,__reset_calls
        caie    1,2
        jrst    fail_17_v1082
        skipn   __scan_error
        jrst    pass_v1082
        jrst    fail_18_v1082
pass_v1082:
        setz    1,
        jrst    done_v1082
fail_1_v1082: movei 1,1
        jrst done_v1082
fail_2_v1082: movei 1,2
        jrst done_v1082
fail_3_v1082: movei 1,3
        jrst done_v1082
fail_4_v1082: movei 1,4
        jrst done_v1082
fail_5_v1082: movei 1,5
        jrst done_v1082
fail_6_v1082: movei 1,6
        jrst done_v1082
fail_7_v1082: movei 1,7
        jrst done_v1082
fail_8_v1082: movei 1,010
        jrst done_v1082
fail_9_v1082: movei 1,011
        jrst done_v1082
fail_10_v1082: movei 1,012
        jrst done_v1082
fail_11_v1082: movei 1,013
        jrst done_v1082
fail_12_v1082: movei 1,014
        jrst done_v1082
fail_13_v1082: movei 1,015
        jrst done_v1082
fail_14_v1082: movei 1,016
        jrst done_v1082
fail_15_v1082: movei 1,017
        jrst done_v1082
fail_16_v1082: movei 1,020
        jrst done_v1082
fail_17_v1082: movei 1,021
        jrst done_v1082
fail_18_v1082: movei 1,022
done_v1082:
        movem   1,__test_exit
        jrst    4,0

; Model only the last-member scan. Enforce the source contract that
; AC3 identifies the leaving slot, which is still in the old session.
        .globl proc_tty_session_has
proc_tty_session_has:
        aos     __scan_calls
        movem   1,__seen_session
        caie    1,5
        setom   __scan_error
        jumpn   2,scan_bad_v1082
        caie    3,3
        setom   __scan_error
        move    1,__peer_present
        popj    17,
scan_bad_v1082:
        setom   __scan_error
        setz    1,
        popj    17,

        .globl proc_tty_line_try_reset_v897
proc_tty_line_try_reset_v897:
        aos     __reset_calls
        jumpn   1,reset_bad_v1082
        skipn   __blocked
        jrst    reset_ok_v1082
reset_bad_v1082:
        seto    1,
        popj    17,
reset_ok_v1082:
        setzm   __line_live
        setz    1,
        popj    17,

        .globl kret_neg1
kret_neg1: seto 1,
        popj 17,

        .data
        .globl proc_current_slot
proc_current_slot: .word 3
        .globl proc_current_ptr
proc_current_ptr: .word __proc
        .globl proc_tty_records
proc_tty_records: .word 040000000005
        .block 024
__proc: .word __uarea,,5
        .word 0
        .word 0
__uarea: .block 024
        .word 020000000050
        .block 0160
__blocked: .word 0
__line_live: .word 0
__peer_present: .word 0
        .globl __reset_calls
__reset_calls: .word 0
        .globl __scan_error
__scan_error: .word 0
        .globl __scan_calls
__scan_calls: .word 0
        .globl __seen_session
__seen_session: .word 0
        .globl __first_return_v1082
__first_return_v1082: .word 0
        .bss
__stack: .block 0400
        .globl __test_exit
__test_exit: .block 1
