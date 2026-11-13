; Native PDP-6 oracle for production v1531 explicit DTFS discard.
; Source-linked VFS/FILE routines; genuine stable u-area layout includes
; a swapped process with no resident VM. Only unrelated physical I/O,
; PIPE/SWAP and MINIT provider-dispatch dependencies are test stubs.
;
; All code/data are ASCII and PDP-6 assembly. Testkit only.
        .text
        .globl main
        .globl vfs_dtfs_discard_slot_v1531
        .globl vfs_dtfs_poisoned_slot_v1531
        .globl file_dtfs_abandon_fd_v1531
        .globl file_mount_busy_v1523
        .globl file_table
        .globl vfs_mount_root_base
        .globl vfs_mount_target_base
        .globl vfs_mount_limit
        .globl vfs_mount_policy
        .globl vfs_namespace_root
        .globl dtfs_media_base
        .globl tsfs_file_shape_base
        .globl tsfs_extent_media_base
        .globl proc_table
        .globl proc_high_slot
        .globl __test_exit
        .globl kret_zero
        .globl kret_neg1
        .globl kconst_2_2
        .globl pipe_fifo_mount_busy
        .globl proc_swap_mount_busy
        .globl fs_provider_reg_call
        .globl file_unlock_mount
        .globl vfs_sync

main:
        ; Mounted noncritical DTFS slot 1 is available only with
        ; WRITE_UNCERTAIN, never merely READ_SUSPECT or no marker.
        ; Set the failure witness BEFORE the first assertion. A failed
        ; first call must never look like main() returning zero.
        movei   4,1
        movem   4,admin_stage_v1531
        movei   1,1
        pushj   17,vfs_dtfs_poisoned_slot_v1531
        jumpn   1,admin_fail_v1531
        movei   1,0
        pushj   17,vfs_dtfs_poisoned_slot_v1531
        jumpe   1,admin_fail_v1531
        movei   1,2
        pushj   17,vfs_dtfs_poisoned_slot_v1531
        jumpe   1,admin_fail_v1531
        movei   4,0200003
        movem   4,media_v1531+1
        movei   1,1
        pushj   17,vfs_dtfs_poisoned_slot_v1531
        jumpe   1,admin_fail_v1531
        movei   4,0400003
        movem   4,media_v1531+1
        ; A poisoned foreign-personality mount is not a native repair/
        ; replacement candidate, even if its provider number is DTFS.
        movei   4,0400013
        movem   4,media_v1531+1
        movei   1,1
        pushj   17,vfs_dtfs_poisoned_slot_v1531
        jumpe   1,admin_fail_v1531
        movei   4,0400003
        movem   4,media_v1531+1

        ; File abandonment refuses an unrelated provider, a clean
        ; DTFS mount, and a nonexistent FD. It changes no other slot.
        movei   4,2
        movem   4,admin_stage_v1531
        move    4,[060202000004]
        movem   4,uarea1_v1531+026
        setz    1,
        pushj   17,file_dtfs_abandon_fd_v1531
        jumpe   1,admin_fail_v1531
        move    4,[050202000004]
        movem   4,uarea1_v1531+026
        movei   4,0200003
        movem   4,media_v1531+1
        setz    1,
        pushj   17,file_dtfs_abandon_fd_v1531
        jumpe   1,admin_fail_v1531
        movei   4,0400003
        movem   4,media_v1531+1
        setz    1,
        pushj   17,file_dtfs_abandon_fd_v1531
        jumpn   1,admin_fail_v1531
        skipn   uarea1_v1531+026
        jrst    admin_check_fd_offset_v1531
        jrst    admin_fail_v1531
admin_check_fd_offset_v1531:
        movei   4,1
        movem   4,uarea1_v1531+027
        movei   1,0
        pushj   17,file_dtfs_abandon_fd_v1531
        jumpe   1,admin_fail_v1531

        ; An otherwise eligible mount with a remote swapped process's
        ; FD15 or cwd must be denied BEFORE physical provider verification.
        movei   4,3
        movem   4,admin_stage_v1531
        move    4,[050202000007]
        movem   4,uarea2_v1531+064
        movei   1,1
        pushj   17,vfs_dtfs_discard_slot_v1531
        jumpe   1,admin_fail_v1531
        skipn   verify_count_v1531
        jrst    admin_remote_cwd_v1531
        jrst    admin_fail_v1531
admin_remote_cwd_v1531:
        setzm   uarea2_v1531+064
        move    4,[050201000000]
        movem   4,uarea2_v1531+025
        movei   1,1
        pushj   17,vfs_dtfs_discard_slot_v1531
        jumpe   1,admin_fail_v1531
        skipn   verify_count_v1531
        jrst    admin_remote_clear_v1531
        jrst    admin_fail_v1531
admin_remote_clear_v1531:
        setzm   uarea2_v1531+025

        ; PIPE/swap references and failed physical verification must
        ; preserve the old mount, media marker and both identity halves.
        movei   4,4
        movem   4,admin_stage_v1531
        setom   pipe_ref_v1531
        movei   1,1
        pushj   17,vfs_dtfs_discard_slot_v1531
        jumpe   1,admin_fail_v1531
        setzm   pipe_ref_v1531
        setom   swap_ref_v1531
        movei   1,1
        pushj   17,vfs_dtfs_discard_slot_v1531
        jumpe   1,admin_fail_v1531
        setzm   swap_ref_v1531
        movei   1,1
        pushj   17,vfs_dtfs_discard_slot_v1531
        jumpe   1,admin_fail_v1531
        move    4,verify_count_v1531
        caie    4,1
        jrst    admin_fail_v1531
        move    4,mount_roots_v1531+1
        came    4,[050201000000]
        jrst    admin_fail_v1531
        move    4,media_v1531+1
        caie    4,0400003
        jrst    admin_fail_v1531
        move    4,ids_hi_v1531+1
        caie    4,012345
        jrst    admin_fail_v1531

        ; Simulate a remote process opening a FILE while the serialized
        ; physical verifier is asleep. The PRECOMMIT recheck must refuse.
        movei   4,5
        movem   4,admin_stage_v1531
        setom   verify_allow_v1531
        setom   verify_inject_v1531
        movei   1,1
        pushj   17,vfs_dtfs_discard_slot_v1531
        jumpe   1,admin_fail_v1531
        move    4,uarea2_v1531+026
        came    4,[050202000013]
        jrst    admin_fail_v1531
        skipn   mount_roots_v1531+1
        jrst    admin_fail_v1531
        skipn   unlock_count_v1531
        jrst    admin_retry_v1531
        jrst    admin_fail_v1531

        ; Final success after explicit remote owner release. Even when
        ; allowed, a clean/non-DTFS/critical root cannot use this path.
admin_retry_v1531:
        movei   4,6
        movem   4,admin_stage_v1531
        setzm   uarea2_v1531+026
        movei   1,1
        pushj   17,vfs_dtfs_discard_slot_v1531
        jumpn   1,admin_fail_v1531
        skipn   mount_roots_v1531+1
        jrst    admin_check_target_v1531
        jrst    admin_fail_v1531
admin_check_target_v1531:
        skipn   mount_targets_v1531+1
        jrst    admin_check_media_v1531
        jrst    admin_fail_v1531
admin_check_media_v1531:
        skipn   media_v1531+1
        jrst    admin_check_ids_v1531
        jrst    admin_fail_v1531
admin_check_ids_v1531:
        skipn   ids_hi_v1531+1
        jrst    admin_check_ids2_v1531
        jrst    admin_fail_v1531
admin_check_ids2_v1531:
        skipn   ids_lo_v1531+1
        jrst    admin_check_other_v1531
        jrst    admin_fail_v1531
admin_check_other_v1531:
        move    4,mount_roots_v1531
        came    4,[060101000003]
        jrst    admin_fail_v1531
        move    4,vfs_namespace_root
        came    4,[060101000003]
        jrst    admin_fail_v1531
        move    4,unlock_count_v1531
        caie    4,1
        jrst    admin_fail_v1531
        movei   1,1
        pushj   17,vfs_dtfs_discard_slot_v1531
        jumpe   1,admin_fail_v1531
        setz    1,
        popj    17,

admin_fail_v1531:
        move    1,admin_stage_v1531
        popj    17,

pipe_fifo_mount_busy:
        move    4,pipe_ref_v1531
        movei   2,0777                 ; deliberately clobber AC2
        move    1,4
        popj    17,
proc_swap_mount_busy:
        move    4,swap_ref_v1531
        movei   2,0777
        move    1,4
        popj    17,
fs_provider_reg_call:
        move    4,6
        caie    4,026
        jrst    kret_neg1
        caie    7,5
        jrst    kret_neg1
        aos     verify_count_v1531
        skipn   verify_allow_v1531
        jrst    kret_neg1
        skipn   verify_inject_v1531
        jrst    kret_zero
        setzm   verify_inject_v1531
        move    4,[050202000013]
        movem   4,uarea2_v1531+026
        jrst    kret_zero
file_unlock_mount:
        caie    1,2
        jrst    kret_neg1
        aos     unlock_count_v1531
        jrst    kret_zero
vfs_sync:
        jrst    kret_neg1               ; poisoned media never syncs
kret_zero:
        setz    1,
        popj    17,
kret_neg1:
        seto    1,
        popj    17,

        .data
kconst_2_2:           .word 2,,2
file_table:            .word uarea1_v1531+026
proc_table:            .word processes_v1531
proc_high_slot:        .word 4
vfs_mount_root_base:   .word mount_roots_v1531
vfs_mount_target_base: .word mount_targets_v1531
vfs_mount_limit:       .word 4
vfs_mount_policy:      .word 2
vfs_namespace_root:    .word 060101000003
dtfs_media_base:       .word media_v1531
tsfs_file_shape_base:  .word ids_hi_v1531
tsfs_extent_media_base:.word ids_lo_v1531
processes_v1531:
        .block 3
        .word uarea1_v1531,,0400000
        .word 0
        .word 0200000000000
        .word uarea2_v1531,,0400000  ; swapped, stable uarea
        .word 0
        .word 0500000000000
        .word uarea3_v1531,,0        ; not owned, stale bytes ignored
        .word 0
        .word 0
mount_roots_v1531:
        .word 060101000003
        .word 050201000000
        .word 0
        .word 0
mount_targets_v1531:
        .word 0
        .word 060001010003
        .word 0
        .word 0
media_v1531:
        .word 0
        .word 0400003
        .word 0
        .word 0
ids_hi_v1531:
        .word 0
        .word 012345
        .word 0
        .word 0
ids_lo_v1531:
        .word 0
        .word 045670
        .word 0
        .word 0
        .bss
uarea1_v1531:         .block 0410
uarea2_v1531:         .block 0410
uarea3_v1531:         .block 0410
pipe_ref_v1531:       .block 1
swap_ref_v1531:       .block 1
verify_count_v1531:   .block 1
verify_allow_v1531:   .block 1
verify_inject_v1531:  .block 1
unlock_count_v1531:   .block 1
admin_stage_v1531:    .block 1
__test_exit:          .block 1
