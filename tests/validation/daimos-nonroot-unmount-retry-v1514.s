; KCORE v1514: real VFS unmount refuses missing non-root media,
; retains the mount, and retires it only after the same device returns.
        .text
        .globl main
        .globl vfs_unmount
        .globl vfs_mount_root_base
        .globl vfs_mount_target_base
        .globl vfs_mount_limit
        .globl vfs_mount_policy
        .globl vfs_mount_aux_base_v1560
        .globl vfs_namespace_root
        .globl kconst_2_2
        .globl pipe_fifo_mount_busy
        .globl proc_swap_mount_busy
        .globl vfs_sync
        .globl fs_provider_reg_call
        .globl file_unlock_mount
        .globl file_mount_busy_v1523
        .globl kret_zero
        .globl kret_neg1
        .globl __test_exit

main:
        setzm   media_online_v1514
        setzm   sync_count_v1514
        setzm   prepare_count_v1514
        setzm   unlock_count_v1514
        movei   1,1
        movem   1,stage_v1514

        ; Secondary D6FS vnode: provider 6, mount ID 2.
        move    1,[060201000003]
        pushj   17,vfs_unmount
        camn    1,[-1]
        jrst    fail_sync_checked_v1514
        jrst    fail_v1514
fail_sync_checked_v1514:
        ; No provider preparation/unlock/slot-retirement after error.
        move    1,vfs_mount_roots_v1514+1
        came    1,[060201000003]
        jrst    fail_v1514
        move    1,vfs_mount_targets_v1514+1
        came    1,[060001010003]
        jrst    fail_v1514
        move    1,vfs_mount_policy
        caie    1,2                     ; readonly bit1 remains
        jrst    fail_v1514
        move    1,sync_count_v1514
        caie    1,1
        jrst    fail_v1514
        skipn   prepare_count_v1514
        jrst    no_prepare_v1514
        jrst    fail_v1514
no_prepare_v1514:
        skipn   unlock_count_v1514
        jrst    media_return_v1514
        jrst    fail_v1514

media_return_v1514:
        movei   1,2
        movem   1,stage_v1514
        setom   media_online_v1514
        move    1,[060201000003]
        pushj   17,vfs_unmount
        jumpn   1,fail_v1514
        skipn   vfs_mount_roots_v1514+1
        jrst    check_secondary_clear_v1514
        jrst    fail_v1514
check_secondary_clear_v1514:
        skipn   vfs_mount_targets_v1514+1
        jrst    check_root_v1514
        jrst    fail_v1514
check_root_v1514:
        move    1,vfs_mount_roots_v1514
        came    1,[060101000003]
        jrst    fail_v1514
        skipn   vfs_mount_targets_v1514
        jrst    check_namespace_v1514
        jrst    fail_v1514
check_namespace_v1514:
        move    1,vfs_namespace_root
        came    1,[060101000003]
        jrst    fail_v1514
        skipn   vfs_mount_policy
        jrst    check_counts_v1514
        jrst    fail_v1514
check_counts_v1514:
        move    1,sync_count_v1514
        caie    1,2
        jrst    fail_v1514
        move    1,prepare_count_v1514
        caie    1,1
        jrst    fail_v1514
        move    1,unlock_count_v1514
        caie    1,1
        jrst    fail_v1514
        setz    1,
        popj    17,
fail_v1514:
        move    1,stage_v1514
        popj    17,

pipe_fifo_mount_busy:
proc_swap_mount_busy:
file_mount_busy_v1523:
        setz    1,
        popj    17,

vfs_sync:
        aos     sync_count_v1514
        skipn   media_online_v1514
        jrst    kret_neg1
        setz    1,
        popj    17,

fs_provider_reg_call:
        caie    7,6                     ; D6FS provider only
        jrst    fail_v1514
        caie    6,020                   ; PREPARE_UNMOUNT
        jrst    fail_v1514
        aos     prepare_count_v1514
        setz    1,
        popj    17,

file_unlock_mount:
        caie    1,2                     ; secondary public mount ID
        jrst    fail_v1514
        aos     unlock_count_v1514
        setz    1,
        popj    17,

kret_zero:
        setz    1,
        popj    17,
kret_neg1:
        seto    1,
        popj    17,

        .data
kconst_2_2: .word 2,,2
vfs_mount_limit: .word 4
vfs_mount_root_base: .word vfs_mount_roots_v1514
vfs_mount_target_base: .word vfs_mount_targets_v1514
vfs_namespace_root: .word 060101000003
vfs_mount_policy: .word 2            ; RO secondary slot bit 1
; The v1560 production helper requires the pre-existing provider-private
; MM mount slab, even though this fixture mounts only D6FS.
vfs_mount_aux_base_v1560: .word vfs_mount_aux_v1560
vfs_mount_aux_v1560: .block 4
vfs_mount_roots_v1514:
        .word 060101000003
        .word 060201000003
        .word 0
        .word 0
vfs_mount_targets_v1514:
        .word 0
        .word 060001010003
        .word 0
        .word 0

        .bss
media_online_v1514: .block 1
sync_count_v1514: .block 1
prepare_count_v1514: .block 1
unlock_count_v1514: .block 1
stage_v1514: .block 1
__test_exit: .block 1
