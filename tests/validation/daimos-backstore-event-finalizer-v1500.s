; Production TERM -> proc_finish_slot -> idle PREVM finalizer.
; Only VM/TTY/MM backend and FILE close are controlled by companion.
        .text
        .globl main
main:
        movei   17,__stack-1
        hrli    17,-0400
        move    1,[010000,,0]       ; target saved user-mode return
        movem   1,__uarea+020
        movei   1,2
        movei   2,1                ; SYS_EVENT_TERM
        pushj   17,proc_event_apply
        camn    1,[-1]
        jrst    refused_v1500
        jrst    fail_v1500
refused_v1500:
        aos     __stage_v1500
        move    1,__close_v1500
        caie    1,1
        jrst    fail_v1500
        move    1,__vm_calls
        caie    1,1
        jrst    fail_v1500
        skipn   __release_calls
        jrst    retained_v1500
        jrst    fail_v1500
retained_v1500:
        move    1,__ptable+6
        trnn    1,0200000          ; TRANSITION still owned
        jrst    fail_v1500
        move    1,__ptable+7
        came    1,[04000,,0]      ; authoritative DISK VM unchanged
        jrst    fail_v1500
        move    1,__uarea+067
        tlnn    1,0400000          ; FINALIZE+PREVM
        jrst    fail_v1500
        tlnn    1,0100000
        jrst    fail_v1500
        hrrz    1,1
        caie    1,0400001         ; terminal TERM status
        jrst    fail_v1500
        move    1,__hup_calls
        caie    1,1
        jrst    fail_v1500

        ; A repeated foreign event must not call FILE/HUP/VM again.
        movei   1,2
        movei   2,1
        pushj   17,proc_event_apply
        camn    1,[-1]
        jrst    duplicate_v1500
        jrst    fail_v1500
duplicate_v1500:
        aos     __stage_v1500
        move    1,__close_v1500
        caie    1,1
        jrst    fail_v1500
        move    1,__vm_calls
        caie    1,1
        jrst    fail_v1500

        ; Actual slot-0 finalizer retries the pre-VM owner and then
        ; twice-rejected u-area MM release without HUP or double VM.
        pushj   17,proc_finish_service_v881
        jumpe   1,first_retry_v1500
        jrst    fail_v1500
first_retry_v1500:
        aos     __stage_v1500
        move    1,__vm_calls
        caie    1,2
        jrst    fail_v1500
        move    1,__ptable+7
        camn    1,[-1]
        jrst    vm_done_v1500
        jrst    fail_v1500
vm_done_v1500:
        move    1,__release_calls
        caie    1,1
        jrst    fail_v1500
        pushj   17,proc_finish_service_v881
        jumpe   1,second_retry_v1500
        jrst    fail_v1500
second_retry_v1500:
        aos     __stage_v1500
        move    1,__release_calls
        caie    1,2
        jrst    fail_v1500
        pushj   17,proc_finish_service_v881
        caie    1,1
        jrst    fail_v1500
        aos     __stage_v1500
        move    1,__release_calls
        caie    1,3
        jrst    fail_v1500
        move    1,__vm_calls
        caie    1,2
        jrst    fail_v1500
        move    1,__hup_calls
        caie    1,1
        jrst    fail_v1500
        move    1,__close_v1500
        caie    1,1
        jrst    fail_v1500
        move    1,__ptable+010
        lsh     1,-041
        caie    1,4                 ; zombie only after all release
        jrst    fail_v1500
        pushj   17,proc_finish_service_v881
        jumpe   1,pass_v1500
        jrst    fail_v1500
pass_v1500:
        setz    1,
        jrst    done_v1500
fail_v1500:
        move    1,__stage_v1500
done_v1500:
        movem   1,__test_exit
        jrst    4,0

        .globl file_close_all_at_v865
file_close_all_at_v865:
        aos     __close_v1500
        setz    1,
        popj    17,
        .globl file_close_all
file_close_all:
        setz    1,
        popj    17,
        .globl proc_fatal_close_current_v879
proc_fatal_close_current_v879:
        seto    1,
        popj    17,
        .globl proc_runq_add
proc_runq_add:
        popj    17,
        .globl fs_provider_wait_event_v917
fs_provider_wait_event_v917:
        popj    17,
        .globl proc_event_nonfatal
proc_event_nonfatal:
        seto    1,
        popj    17,
        .globl kret_neg1
kret_neg1:
        seto    1,
        popj    17,

        .data
__close_v1500: .word 0
__stage_v1500: .word 1
