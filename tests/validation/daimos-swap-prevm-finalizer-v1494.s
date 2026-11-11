; Production PREVM slot-0 finalizer after swap backing refuses a release.
; The VM leaf is controlled: first call refuses; second accepts.
        .text
        .globl main
main:
        movei   17,__stack-1
        hrli    17,-0400
        move    1,[010000,,0]
        movem   1,__uarea+020
        movei   1,2
        movei   2,012345
        pushj   17,proc_finish_slot
        camn    1,[-1]
        jrst    refused_v1494
        jrst    fail_v1494
refused_v1494:
        move    1,__vm_calls
        caie    1,1
        jrst    fail_v1494
        skipn   __release_calls
        jrst    check_owner_v1494
        jrst    fail_v1494
check_owner_v1494:
        move    1,__ptable+6
        trnn    1,0200000              ; TRANSITION preserved
        jrst    fail_v1494
        move    1,__ptable+7
        came    1,[04000,,020000]      ; VM still owned
        jrst    fail_v1494
        move    1,__uarea+067
        tlnn    1,0400000              ; FINALIZE
        jrst    fail_v1494
        tlnn    1,0100000              ; PREVM
        jrst    fail_v1494
        hrrz    1,1
        caie    1,012345
        jrst    fail_v1494
        move    1,proc_finish_last_tick_v881
        tlnn    1,0400000              ; pending idle retry
        jrst    fail_v1494
        move    1,__hup_calls
        caie    1,1
        jrst    fail_v1494
        move    1,__tty_calls
        caie    1,1
        jrst    fail_v1494

        ; Retry the retained PREVM owner with actual idle finalizer.
        pushj   17,proc_finish_service_v881
        jumpe   1,vm_retry_v1494
        jrst    fail_v1494
vm_retry_v1494:
        move    1,__vm_calls
        caie    1,2
        jrst    fail_v1494
        move    1,__ptable+7
        camn    1,[-1]                 ; VM_NONE published after success
        jrst    after_vm_v1494
        jrst    fail_v1494
after_vm_v1494:
        move    1,__release_calls
        caie    1,1                    ; first u-area release refused
        jrst    fail_v1494
        move    1,__hup_calls
        caie    1,1                    ; no repeat sleeping HUP
        jrst    fail_v1494

        pushj   17,proc_finish_service_v881
        jumpe   1,second_retry_v1494
        jrst    fail_v1494
second_retry_v1494:
        move    1,__release_calls
        caie    1,2
        jrst    fail_v1494
        move    1,__vm_calls
        caie    1,2                    ; no repeated backing free
        jrst    fail_v1494
        pushj   17,proc_finish_service_v881
        caie    1,1                    ; last live slot retired
        jrst    fail_v1494
        move    1,__release_calls
        caie    1,3
        jrst    fail_v1494
        move    1,__vm_calls
        caie    1,2
        jrst    fail_v1494
        move    1,__hup_calls
        caie    1,1
        jrst    fail_v1494
        move    1,__runq_calls
        caie    1,1
        jrst    fail_v1494
        move    1,__ptable+010
        lsh     1,-041
        caie    1,4                    ; ZOMB
        jrst    fail_v1494
        pushj   17,proc_finish_service_v881
        jumpe   1,pass_v1494
        jrst    fail_v1494
pass_v1494:
        setz    1,
        jrst    done_v1494
fail_v1494:
        movei   1,1
done_v1494:
        movem   1,__test_exit
        jrst    4,0
