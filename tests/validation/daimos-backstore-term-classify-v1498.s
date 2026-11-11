; Real PDP-6 proc_event_apply, with controlled foreign finalizer.
; A disk-resident process's u-area exists even while its VM is absent.
        .text
        .globl main
main:
        movei   17,__stack-1
        hrli    17,-0400
        ; A kernel WAIT_CHILD continuation must not be remotely destroyed.
        move    1,[040000,,0]
        iorm    1,__ptable+010
        movei   1,2
        movei   2,1
        pushj   17,proc_event_apply
        jumpe   1,wait_deferred_v1498
        jrst    fail_v1498
wait_deferred_v1498:
        aos     __stage
        move    1,__victim+024
        tlnn    1,004                  ; pending TERM recorded
        jrst    fail_v1498
        skipn   __close_calls
        jrst    wait_close_ok_v1498
        jrst    fail_v1498
wait_close_ok_v1498:
        skipn   __finish_calls
        jrst    repeated_v1498
        jrst    fail_v1498
repeated_v1498:
        movei   1,2
        movei   2,1
        pushj   17,proc_event_apply
        jumpe   1,after_repeat_v1498
        jrst    fail_v1498
after_repeat_v1498:
        aos     __stage
        skipn   __finish_calls
        jrst    saved_exec_v1498
        jrst    fail_v1498

saved_exec_v1498:
        aos     __stage
        ; Wait was cleared, but the saved PC still names executive mode.
        movsi   1,040000
        andcam  1,__ptable+010
        setzm   __victim+020
        movsi   1,004
        andcam  1,__victim+024
        movei   1,2
        movei   2,1
        pushj   17,proc_event_apply
        jumpe   1,exec_deferred_v1498
        jrst    fail_v1498
exec_deferred_v1498:
        aos     __stage
        move    1,__victim+024
        tlnn    1,004
        jrst    fail_v1498
        skipn   __finish_calls
        jrst    user_return_v1498
        jrst    fail_v1498

        ; An owner with no WAIT, no prior event, and a user-mode saved
        ; return may enter foreign finalization. A refused VM destroy
        ; is NOT a successful TERM, and the disk owner must survive.
user_return_v1498:
        aos     __stage
        movsi   1,004
        andcam  1,__victim+024
        move    1,[010000,,0]
        movem   1,__victim+020
        movei   1,2
        movei   2,1
        pushj   17,proc_event_apply
        camn    1,[-1]
        jrst    failed_vm_v1498
        jrst    fail_v1498
failed_vm_v1498:
        aos     __stage
        move    1,__finish_calls
        caie    1,1
        jrst    fail_v1498
        move    1,__close_calls
        caie    1,1
        jrst    fail_v1498
        move    1,__ptable+6
        trne    1,0200000
        jrst    fail_v1498
        move    1,__ptable+7
        came    1,[04000,,0]         ; still nonresident, owned
        jrst    fail_v1498
        move    1,__victim+067
        tlnn    1,0400000
        jrst    commit_v1498
        jrst    fail_v1498

commit_v1498:
        aos     __stage
        movei   1,2
        movei   2,1
        pushj   17,proc_event_apply
        jumpe   1,finalized_v1498
        jrst    fail_v1498
finalized_v1498:
        aos     __stage
        move    1,__finish_calls
        caie    1,2
        jrst    fail_v1498
        move    1,__close_calls
        caie    1,2
        jrst    fail_v1498
        move    1,__ptable+6
        trnn    1,0200000
        jrst    fail_v1498
        move    1,__ptable+7
        camn    1,[-1]
        jrst    final_blocked_v1498
        jrst    fail_v1498
final_blocked_v1498:
        aos     __stage
        movei   1,2
        movei   2,1
        pushj   17,proc_event_apply
        camn    1,[-1]
        jrst    pass_v1498
        jrst    fail_v1498
pass_v1498:
        setz    1,
        jrst    done_v1498
fail_v1498:
        move    1,__close_calls
        lsh     1,6
        add     1,__finish_calls
        lsh     1,6
        add     1,__stage
done_v1498:
        movem   1,__test_exit
        jrst    4,0

        .globl proc_current_slot
        .globl proc_table
        .globl file_close_all_at_v865
        .globl file_close_all
        .globl proc_fatal_close_current_v879
        .globl proc_runq_add
        .globl fs_provider_wait_event_v917
        .globl proc_finish_slot
        .globl proc_event_nonfatal
        .globl kret_neg1
file_close_all_at_v865:
        aos     __close_calls
        setz    1,
        popj    17,
file_close_all:
proc_fatal_close_current_v879:
        movei   1,0777
        popj    17,
proc_runq_add:
fs_provider_wait_event_v917:
        popj    17,
proc_event_nonfatal:
        seto    1,
        popj    17,
proc_finish_slot:
        aos     __finish_calls
        move    3,__finish_calls
        caie    3,1
        jrst    commit_owner_v1498
        seto    1,                   ; refused VM destroy
        popj    17,
commit_owner_v1498:
        move    3,__ptable+6
        iori    3,0200000
        movem   3,__ptable+6
        setom   __ptable+7
        setz    1,
        popj    17,
kret_neg1:
        seto    1,
        popj    17,

        .data
proc_table: .word __ptable
proc_current_slot: .word 1
__ptable: .block 6
        .word __victim,,0400407
        .word 04000,,0               ; nonresident DISK owner
        .word 0200000,,0             ; runnable, no WAIT initially
__victim: .block 024
        .word 0                      ; FD control, no pending events
        .block 067-025
        .word 0                      ; FINALIZE status
        .block 0407-070
__close_calls: .word 0
__finish_calls: .word 0
__stage: .word 1
        .bss
__stack: .block 0400
        .globl __test_exit
__test_exit: .block 1
