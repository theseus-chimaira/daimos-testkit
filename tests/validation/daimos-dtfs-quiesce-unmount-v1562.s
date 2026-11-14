; v1562: source-linked real VFS unmount, with an admission attempt at SYNC.
; Simulated provider completion does not claim physical Type-551 CLEAN I/O.
        .text
        .globl main
        .globl vfs_unmount
        .globl vfs_dtfs_owner_admit_v1562
        .globl vfs_mount_root_base
        .globl vfs_mount_target_base
        .globl vfs_mount_limit
        .globl vfs_mount_policy
        .globl vfs_mount_aux_base_v1560
        .globl dtfs_media_base
        .globl vfs_namespace_root
        .globl kconst_1_1
        .globl kconst_2_2
        .globl kconst_3_3
        .globl pipe_fifo_mount_busy
        .globl proc_swap_mount_busy
        .globl file_mount_busy_v1523
        .globl vfs_sync
        .globl fs_provider_reg_call
        .globl file_unlock_mount
        .globl kret_zero
        .globl kret_neg1
        .globl __test_exit

main:
        movei   010,cases_v1562
        movei   011,case_count_v1562
next_case_v1562:
        setzm   sync_count_v1562
        setzm   unlock_count_v1562
        setzm   bad_audit_v1562
        setzm   attempted_v1562
        movei   1,2                     ; restore RO bitmap for slot 1
        movem   1,vfs_mount_policy
        move    1,[060001010003]
        movem   1,targets_v1562+1
        move    1,(010)                 ; provider-5 slot 1 root
        movem   1,roots_v1562+1
        move    1,1(010)                ; media RH including V2 flags
        movem   1,media_v1562+1
        move    1,2(010)                ; retained MM basep
        movem   1,aux_v1562+1
        move    1,3(010)                ; sync should report error
        movem   1,sync_error_v1562
        move    1,4(010)                ; attempt to publish FILE at SYNC
        movem   1,injected_open_v1562
        move    1,5(010)                ; initial remote owner
        movem   1,owner_busy_v1562
        move    1,[050201000000]       ; original public DTFS mount 2
        pushj   17,vfs_unmount
        came    1,6(010)
        jrst    fail_v1562
        move    1,roots_v1562+1
        came    1,7(010)
        jrst    fail_v1562
        move    1,media_v1562+1
        came    1,010(010)
        jrst    fail_v1562
        move    1,sync_count_v1562
        came    1,011(010)
        jrst    fail_v1562
        move    1,attempted_v1562
        came    1,012(010)
        jrst    fail_v1562
        move    1,unlock_count_v1562
        came    1,013(010)
        jrst    fail_v1562
        move    1,owner_busy_v1562
        came    1,014(010)
        jrst    fail_v1562
        skipn   bad_audit_v1562
        jrst    next_case_good_v1562
        jrst    fail_v1562
next_case_good_v1562:
        addi    010,015                ; 13 decimal case words
        sojg    011,next_case_v1562
        setz    1,
        popj    17,
fail_v1562:
        move    1,011
        popj    17,

pipe_fifo_mount_busy:
proc_swap_mount_busy:
        jrst    kret_zero
file_mount_busy_v1523:
        move    1,owner_busy_v1562
        popj    17,

; A VFS SYNC may release the scheduler. Model a concurrent foreign OPEN
; just before the completion, using the actual v1562 admission helper.
vfs_sync:
        aos     sync_count_v1562
        skipn   injected_open_v1562
        jrst    sync_result_v1562
        move    1,[050202000003]
        pushj   17,vfs_dtfs_owner_admit_v1562
        movem   1,attempted_v1562
        jumpe   1,sync_new_owner_v1562
        jrst    sync_result_v1562
sync_new_owner_v1562:
        setom   owner_busy_v1562       ; only if admission truly succeeded
sync_result_v1562:
        skipn   sync_error_v1562
        jrst    kret_zero
        jrst    kret_neg1

fs_provider_reg_call:
        setom   bad_audit_v1562        ; DTFS has no PREPARE_UNMOUNT
        jrst    kret_neg1
file_unlock_mount:
        caie    1,2
        jrst    bad_unlock_v1562
        aos     unlock_count_v1562
        jrst    kret_zero
bad_unlock_v1562:
        setom   bad_audit_v1562
        jrst    kret_neg1
kret_zero:
        setz    1,
        popj    17,
kret_neg1:
        seto    1,
        popj    17,

        .data
        .globl cases_v1562
        .globl case_count_v1562
kconst_1_1: .word 1,,1
kconst_2_2: .word 2,,2
kconst_3_3: .word 3,,3
vfs_mount_limit: .word 3
vfs_mount_policy: .word 2             ; initial RO secondary V2 slot
vfs_mount_root_base: .word roots_v1562
vfs_mount_target_base: .word targets_v1562
dtfs_media_base: .word media_v1562
vfs_mount_aux_base_v1560: .word aux_v1562
vfs_namespace_root: .word 060101000003
roots_v1562:
        .word 060101000003
        .word 050201000000
        .word 0
targets_v1562:
        .word 0
        .word 060001010003
        .word 0
media_v1562: .block 3
aux_v1562: .block 3
        .bss
sync_error_v1562: .block 1
injected_open_v1562: .block 1
owner_busy_v1562: .block 1
attempted_v1562: .block 1
sync_count_v1562: .block 1
unlock_count_v1562: .block 1
bad_audit_v1562: .block 1
__test_exit: .block 1
