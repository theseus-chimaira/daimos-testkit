; Real deferred TERM event/return helpers with a DISK owner.
; Only the final private process-exit service is a controlled witness.
        .text
        .globl main
main:
        movei   17,__stack-1
        hrli    17,-0400
        ; Nonresident process has a live saved executive continuation.
        movsi   1,040000              ; WAIT_CHILD
        iorm    1,__ptable+010
        setzm   __uarea+020           ; saved PC executive mode
        movei   1,2
        movei   2,1                   ; TERM
        pushj   17,proc_event_apply
        jumpe   1,recorded_v1501
        jrst    fail_v1501
recorded_v1501:
        aos     __stage_v1501
        move    1,__uarea+024
        tlnn    1,004
        jrst    fail_v1501
        skipn   __owner_calls_v1501
        jrst    not_exited_v1501
        jrst    fail_v1501
not_exited_v1501:
        move    1,__ptable+7
        came    1,[04000,,0]          ; backed DISK record untouched
        jrst    fail_v1501
        skipn   __foreign_close_v1501
        jrst    coalesced_v1501
        jrst    fail_v1501
coalesced_v1501:
        movei   1,2
        movei   2,1
        pushj   17,proc_event_apply
        jumpe   1,after_repeat_v1501
        jrst    fail_v1501
after_repeat_v1501:
        aos     __stage_v1501
        skipn   __foreign_close_v1501
        jrst    repaired_v1501
        jrst    fail_v1501

repaired_v1501:
        ; Controlled swap recovery returns a resident VM, clears WAIT
        ; and completes the saved executive continuation. The same
        ; owner then passes through its actual syscall-return helper.
        move    1,[04000,,020000]
        movem   1,__ptable+7
        movsi   1,040000
        andcam  1,__ptable+010
        move    1,[010000,,0]
        movem   1,__uarea+020
        movei   1,2
        movem   1,proc_current_slot
        pushj   17,proc_deferred_term_check_v926
        aos     __stage_v1501
        move    1,__owner_calls_v1501
        caie    1,1
        jrst    fail_v1501
        move    1,__exit_status_v1501
        caie    1,0400001
        jrst    fail_v1501
        move    1,__uarea+024
        tlne    1,004                  ; consumed exactly once
        jrst    fail_v1501
        trnn    1,04                   ; owner fatal-close latch
        jrst    fail_v1501
        skipn   __foreign_close_v1501
        jrst    owner_retry_v1501
        jrst    fail_v1501
owner_retry_v1501:
        pushj   17,proc_deferred_term_check_v926
        aos     __stage_v1501
        move    1,__owner_calls_v1501
        caie    1,1
        jrst    fail_v1501

        ; A concurrent foreign TERM cannot tear down the owner while
        ; its private fatal close holds the existing ownership bit.
        movei   1,1
        movem   1,proc_current_slot
        movei   1,2
        movei   2,1
        pushj   17,proc_event_apply
        camn    1,[-1]
        jrst    foreign_rejected_v1501
        jrst    fail_v1501
foreign_rejected_v1501:
        aos     __stage_v1501
        move    1,__owner_calls_v1501
        caie    1,1
        jrst    fail_v1501
        skipn   __foreign_close_v1501
        jrst    pass_v1501
        jrst    fail_v1501
pass_v1501:
        setz    1,
        jrst    done_v1501
fail_v1501:
        move    1,__stage_v1501
done_v1501:
        movem   1,__test_exit
        jrst    4,0

        .globl proc_fatal_close_current_v879
proc_fatal_close_current_v879:
        aos     __owner_calls_v1501
        movem   1,__exit_status_v1501
        setz    1,
        popj    17,
        .globl file_close_all_at_v865
file_close_all_at_v865:
        aos     __foreign_close_v1501
        setz    1,
        popj    17,
        .globl file_close_all
file_close_all:
        aos     __foreign_close_v1501
        setz    1,
        popj    17,
        .globl proc_finish_slot
proc_finish_slot:
        aos     __foreign_close_v1501
        setz    1,
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
        .globl proc_table
proc_table: .word __ptable
        .globl proc_current_slot
proc_current_slot: .word 1
        .globl file_table
file_table: .word __uarea+026
__ptable: .block 6
        .word __uarea,,0400407
        .word 04000,,0
        .word 0200000,,0
__uarea: .block 0100
__stage_v1501: .word 1
__owner_calls_v1501: .word 0
__exit_status_v1501: .word 0
__foreign_close_v1501: .word 0
        .bss
__stack: .block 0400
        .globl __test_exit
__test_exit: .block 1
