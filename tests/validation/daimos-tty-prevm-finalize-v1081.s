; PDP-6 real process-finalizer: a last-session TTY refuses once.
; VM must remain live, PREVM must own retry, and VM/u-area finalize
; exactly once after the TTY's memory provider accepts the release.
        .text
        .globl main
main:
        movei   17,__stack-1
        hrli    17,-0400
        move    1,[010000,,0]       ; saved user return
        movem   1,__uarea+020
        movei   1,2
        movei   2,012345
        pushj   17,proc_finish_slot
        camn    1,[-1]
        jrst    first_refused_v1081
        jrst    fail_1_v1081
first_refused_v1081:
        move    1,__tty_calls
        caie    1,1
        jrst    fail_2_v1081
        skipn   __vm_calls
        jrst    no_vm_yet_v1081
        jrst    fail_3_v1081
no_vm_yet_v1081:
        skipn   __release_calls
        jrst    verify_prevm_v1081
        jrst    fail_4_v1081
verify_prevm_v1081:
        move    1,__uarea+067
        tlne    1,0100000           ; PREVM
        jrst    verify_mark_v1081
        jrst    fail_5_v1081
verify_mark_v1081:
        tlne    1,0400000           ; FINALIZE
        jrst    verify_live_v1081
        jrst    fail_6_v1081
verify_live_v1081:
        move    1,__ptable+7       ; VM not destroyed
        camn    1,[04000,,020000]
        jrst    retry_one_v1081
        jrst    fail_7_v1081
retry_one_v1081:
        pushj   17,proc_finish_service_v881
        jumpe   1,first_stage_v1081
        jrst    fail_8_v1081
first_stage_v1081:
        move    1,__tty_calls
        caie    1,2                ; retry accepted
        jrst    fail_9_v1081
        move    1,__vm_calls
        caie    1,1
        jrst    fail_10_v1081
        move    1,__release_calls
        caie    1,1
        jrst    fail_11_v1081
        ; Only u-area MM rejects subsequent calls; do not revisit TTY/VM.
        pushj   17,proc_finish_service_v881
        jumpe   1,check_second_v1081
        jrst    fail_12_v1081
check_second_v1081:
        pushj   17,proc_finish_service_v881
        caie    1,1
        jrst    fail_13_v1081
        move    1,__tty_calls
        caie    1,2
        jrst    fail_14_v1081
        move    1,__vm_calls
        caie    1,1
        jrst    fail_15_v1081
        move    1,__release_calls
        caie    1,3
        jrst    fail_16_v1081
        move    1,__uarea+067
        hrrz    1,1
        caie    1,012345
        jrst    fail_17_v1081
        setz    1,
        jrst    done_v1081
fail_1_v1081:  movei 1,1
        jrst done_v1081
fail_2_v1081:  movei 1,2
        jrst done_v1081
fail_3_v1081:  movei 1,3
        jrst done_v1081
fail_4_v1081:  movei 1,4
        jrst done_v1081
fail_5_v1081:  movei 1,5
        jrst done_v1081
fail_6_v1081:  movei 1,6
        jrst done_v1081
fail_7_v1081:  movei 1,7
        jrst done_v1081
fail_8_v1081:  movei 1,010
        jrst done_v1081
fail_9_v1081:  movei 1,011
        jrst done_v1081
fail_10_v1081: movei 1,012
        jrst done_v1081
fail_11_v1081: movei 1,013
        jrst done_v1081
fail_12_v1081: movei 1,014
        jrst done_v1081
fail_13_v1081: movei 1,015
        jrst done_v1081
fail_14_v1081: movei 1,016
        jrst done_v1081
fail_15_v1081: movei 1,017
        jrst done_v1081
fail_16_v1081: movei 1,020
        jrst done_v1081
fail_17_v1081: movei 1,021
done_v1081:
        movem   1,__test_exit
        jrst    4,0
