; Real KCORE VFS unmount and FILE mount-reference scan on PDP-6.
; The data are real three-word process descriptors and stable 0410-word
; u-areas, including one process with no resident user VM (swapped).
; Stubbed dependencies are only unrelated PIPE/SWAP and physical SYNC.
        .text
        .globl main
        .globl vfs_unmount
        .globl file_mount_busy_v1523
        .globl proc_table
        .globl proc_high_slot
        .globl vfs_mount_target_base
        .globl vfs_mount_root_base
        .globl vfs_mount_limit
        .globl vfs_mount_policy
        .globl vfs_mount_aux_base_v1560
        .globl dtfs_media_base
        .globl vfs_namespace_root
        .globl kconst_2_2
        .globl kconst_1_1
        .globl kconst_3_3
        .globl pipe_fifo_mount_busy
        .globl proc_swap_mount_busy
        .globl vfs_sync
        .globl fs_provider_reg_call
        .globl file_unlock_mount
        .globl kret_zero
        .globl kret_neg1
        .globl __test_exit

main:
        ; Process 1 owns an ordinary OPEN vnode on secondary mount ID 2.
        ; Process 2 has a different stable u-area and NO resident VM.
        movei   4,1
        movem   4,stage_v1523
        move    4,[050202000001]
        movem   4,uarea1_v1523+026
        move    4,[050402000001]
        movem   4,uarea3_v1523+026   ; no u-area ownership: never scan it
        movei   1,2
        pushj   17,file_mount_busy_v1523
        caie    1,1
        jrst    fail_v1523
        pushj   17,try_unmount_v1523
        camn    1,[-1]
        jrst    check_held_v1523
        jrst    fail_v1523
check_held_v1523:
        skipn   sync_count_v1523
        jrst    check_hold_mount_v1523
        jrst    fail_v1523
check_hold_mount_v1523:
        move    4,mount_roots_v1523+1
        came    4,[050201000000]
        jrst    fail_v1523

        ; The last FILE descriptor in a different, swapped process
        ; must prevent unmount even if the caller's FILE table is clear.
        movei   4,2
        movem   4,stage_v1523
        setzm   uarea1_v1523+026
        move    4,[050202000002]
        movem   4,uarea2_v1523+064   ; FD15 = 026 + 15*2 = 064
        movei   1,2
        pushj   17,file_mount_busy_v1523
        caie    1,1
        jrst    fail_v1523
        pushj   17,try_unmount_v1523
        camn    1,[-1]
        jrst    check_swapped_v1523
        jrst    fail_v1523
check_swapped_v1523:
        skipn   sync_count_v1523
        jrst    check_cwd_v1523
        jrst    fail_v1523

        ; Closing FD15 is insufficient while remote cwd is on mount 2.
check_cwd_v1523:
        movei   4,3
        movem   4,stage_v1523
        setzm   uarea2_v1523+064
        move    4,[050201000000]
        movem   4,uarea2_v1523+025
        movei   1,2
        pushj   17,file_mount_busy_v1523
        caie    1,1
        jrst    fail_v1523
        pushj   17,try_unmount_v1523
        camn    1,[-1]
        jrst    close_cwd_v1523
        jrst    fail_v1523
close_cwd_v1523:
        skipn   sync_count_v1523
        jrst    check_offline_v1523
        jrst    fail_v1523

        ; No live references. An unrelated u-area with no ownership bit
        ; contains a deliberately stale vnode and must not block.
check_offline_v1523:
        movei   4,4
        movem   4,stage_v1523
        setzm   uarea2_v1523+025
        movei   1,2
        pushj   17,file_mount_busy_v1523
        jumpn   1,fail_v1523
        pushj   17,try_unmount_v1523
        camn    1,[-1]
        jrst    check_phys_error_v1523
        jrst    fail_v1523
check_phys_error_v1523:
        move    4,sync_count_v1523
        caie    4,1
        jrst    fail_v1523
        skipn   unlock_count_v1523
        jrst    check_no_retire_v1523
        jrst    fail_v1523
check_no_retire_v1523:
        move    4,mount_roots_v1523+1
        came    4,[050201000000]
        jrst    fail_v1523

        ; A second process opens a fresh FILE while SYNC sleeps. The
        ; preflight check passed, but the precommit recheck MUST refuse.
        movei   4,5
        movem   4,stage_v1523
        setom   media_online_v1523
        setom   inject_open_v1523
        pushj   17,try_unmount_v1523
        camn    1,[-1]
        jrst    check_racing_open_v1523
        jrst    fail_v1523
check_racing_open_v1523:
        move    4,mount_roots_v1523+1
        came    4,[050201000000]
        jrst    fail_v1523
        move    4,uarea2_v1523+026
        came    4,[050202000003]
        jrst    fail_v1523
        move    4,sync_count_v1523
        caie    4,2
        jrst    fail_v1523
        skipn   unlock_count_v1523
        jrst    close_racing_open_v1523
        jrst    fail_v1523

        ; Only after the actual remote FILE closes can a verified
        ; healthy mount complete retirement and permit slot reuse.
close_racing_open_v1523:
        movei   4,6
        movem   4,stage_v1523
        setzm   uarea2_v1523+026
        pushj   17,try_unmount_v1523
        jumpn   1,fail_v1523
        skipn   mount_roots_v1523+1
        jrst    check_retired_target_v1523
        jrst    fail_v1523
check_retired_target_v1523:
        skipn   mount_targets_v1523+1
        jrst    check_root_v1523
        jrst    fail_v1523
check_root_v1523:
        move    4,mount_roots_v1523
        came    4,[060101000003]
        jrst    fail_v1523
        move    4,vfs_namespace_root
        came    4,[060101000003]
        jrst    fail_v1523
        move    4,sync_count_v1523
        caie    4,3
        jrst    fail_v1523
        move    4,unlock_count_v1523
        caie    4,1
        jrst    fail_v1523
        move    4,pipe_checks_v1523
        caie    4,010
        jrst    fail_v1523
        move    4,swap_checks_v1523
        caie    4,010
        jrst    fail_v1523
success_v1523:
        setz    1,
        popj    17,
fail_v1523:
        move    1,stage_v1523
        popj    17,

try_unmount_v1523:
        move    1,[050201000000]
        jrst    vfs_unmount

; Each checker destroys AC2 deliberately. VFS must reload the saved
; zero-based slot before calling the next checker.
pipe_fifo_mount_busy:
        aos     pipe_checks_v1523
        caie    1,2
        jrst    kret_neg1
        movei   2,0777
        jrst    kret_zero
proc_swap_mount_busy:
        aos     swap_checks_v1523
        caie    1,2
        jrst    kret_neg1
        movei   2,0777
        jrst    kret_zero
vfs_sync:
        aos     sync_count_v1523
        skipn   media_online_v1523
        jrst    kret_neg1
        skipn   inject_open_v1523
        jrst    kret_zero
        setzm   inject_open_v1523
        move    4,[050202000003]
        movem   4,uarea2_v1523+026
        jrst    kret_zero
fs_provider_reg_call:
        jrst    kret_neg1            ; DTFS must not call D6FS prepare
file_unlock_mount:
        caie    1,2
        jrst    kret_neg1
        aos     unlock_count_v1523
        jrst    kret_zero
kret_zero:
        setz    1,
        popj    17,
kret_neg1:
        seto    1,
        popj    17,

        .data
kconst_2_2: .word 2,,2
kconst_1_1: .word 1,,1
kconst_3_3: .word 3,,3
proc_table: .word processes_v1523
proc_high_slot: .word 4
vfs_mount_limit: .word 4
vfs_mount_target_base: .word mount_targets_v1523
vfs_mount_root_base: .word mount_roots_v1523
vfs_mount_policy: .word 2
; No outstanding DTFS intent owner in this earlier FILE/cwd regression.
vfs_mount_aux_base_v1560: .word mount_aux_v1560
mount_aux_v1560: .block 4
dtfs_media_base: .word mount_media_v1562
mount_media_v1562: .block 4
vfs_namespace_root: .word 060101000003
processes_v1523:
        .block 3                    ; slot 0: idle, no u-area
        .word uarea1_v1523,,0400000 ; slot 1, current process
        .word 0
        .word 0200000000000
        .word uarea2_v1523,,0400000 ; slot 2, swapped user process
        .word 0                     ; NO resident VM
        .word 0500000000000
        .word uarea3_v1523,,0       ; slot 3 is unused / no u-area
        .word 0
        .word 0
mount_roots_v1523:
        .word 060101000003
        .word 050201000000
        .word 0
        .word 0
mount_targets_v1523:
        .word 0
        .word 060001010003
        .word 0
        .word 0
        .bss
uarea1_v1523: .block 0410
uarea2_v1523: .block 0410
uarea3_v1523: .block 0410
media_online_v1523: .block 1
inject_open_v1523: .block 1
sync_count_v1523: .block 1
unlock_count_v1523: .block 1
pipe_checks_v1523: .block 1
swap_checks_v1523: .block 1
stage_v1523: .block 1
__test_exit: .block 1
