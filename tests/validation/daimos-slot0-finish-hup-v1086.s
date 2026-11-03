; Slot 0 executes actual proc_finish_slot with an explicit PREVM owner
; already published by proc_exit_current. Rejected u-area MM release
; must retry using only the non-sleeping stage, not session HUP.
        .text
        .globl main
main:
        movei 17,__stack-1
        hrli 17,-0400
        setzm __test_exit
        movsi 1,0500000         ; FINALIZE+PREVM
        hrr 1,[01234]
        movem 1,__uarea+067
        movei 1,0200000
        iorm 1,__ptable+6       ; TRANSITION owner
        movei 1,2
        movei 2,01234
        pushj 17,proc_finish_slot_owner_v932
        camn 1,[-1]
        jrst first_mm_busy_v1086
        jrst fail_1_v1086
first_mm_busy_v1086:
        skipn __hup_calls
        jrst first_no_hup_v1086
        jrst fail_2_v1086
first_no_hup_v1086:
        move 1,__tty_calls
        caie 1,1
        jrst fail_3_v1086
        move 1,__vm_calls
        caie 1,1
        jrst fail_4_v1086
        move 1,__release_calls
        caie 1,1
        jrst fail_5_v1086
        ; Two idle retries: first MM_BUSY, then successful u-area free.
        pushj 17,proc_finish_service_v881
        pushj 17,proc_finish_service_v881
        skipn __hup_calls
        jrst check_final_v1086
        jrst fail_6_v1086
check_final_v1086:
        move 1,__tty_calls
        caie 1,1
        jrst fail_7_v1086
        move 1,__vm_calls
        caie 1,1
        jrst fail_8_v1086
        move 1,__release_calls
        caie 1,3
        jrst fail_9_v1086
        setz 1,
        jrst done_v1086
fail_1_v1086: movei 1,1
        jrst done_v1086
fail_2_v1086: movei 1,2
        jrst done_v1086
fail_3_v1086: movei 1,3
        jrst done_v1086
fail_4_v1086: movei 1,4
        jrst done_v1086
fail_5_v1086: movei 1,5
        jrst done_v1086
fail_6_v1086: movei 1,6
        jrst done_v1086
fail_7_v1086: movei 1,7
        jrst done_v1086
fail_8_v1086: movei 1,010
        jrst done_v1086
fail_9_v1086: movei 1,011
done_v1086:
        movem 1,__test_exit
        jrst 4,0
