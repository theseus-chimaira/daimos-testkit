; Actual native v1566 resident VFS UNMOUNT, including its real v1562
; owner/aux checks and quiescence helpers. The only model boundary is
; physical/provider completion, which runs after VFS acquired the bit.
        .text
        .globl main
        .globl vfs_unmount
        .globl vfs_dtfs_aux_empty_v1560
        .globl vfs_dtfs_quiesce_begin_v1562
        .globl vfs_dtfs_quiesce_end_v1562
        .globl vfs_mount_root_base
        .globl vfs_mount_target_base
        .globl vfs_mount_policy
        .globl vfs_mount_limit
        .globl dtfs_media_base
        .globl vfs_mount_aux_base_v1560
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
        movei   010,cases_v1566
        movei   011,case_count_v1566
case_next_v1566:
        setzm   calls_v1566
        setzm   sync_count_v1566
        setzm   unlocks_v1566
        setzm   bad_v1566
        move    1,(010)
        movem   1,mode_v1566
        move    1,1(010)
        movem   1,media_v1566+1
        move    1,2(010)
        movem   1,aux_v1566+1
        move    1,3(010)
        movem   1,vfs_mount_policy
        move    1,4(010)
        movem   1,owner_v1566
        move    1,5(010)
        movem   1,sync_error_v1566
        move    1,[050201000000]       ; published DTFS slot1 root
        movem   1,roots_v1566+1
        move    1,[060001010003]       ; nonzero mountpoint
        movem   1,targets_v1566+1
        move    1,[050201000000]
        pushj   17,vfs_unmount
        came    1,6(010)
        jrst    case_bad_v1566
        move    1,roots_v1566+1
        came    1,7(010)
        jrst    case_bad_v1566
        move    1,media_v1566+1
        came    1,010(010)
        jrst    case_bad_v1566
        move    1,aux_v1566+1
        came    1,011(010)
        jrst    case_bad_v1566
        move    1,calls_v1566
        came    1,012(010)
        jrst    case_bad_v1566
        move    1,sync_count_v1566
        came    1,013(010)
        jrst    case_bad_v1566
        move    1,unlocks_v1566
        came    1,014(010)
        jrst    case_bad_v1566
        move    1,owner_v1566
        came    1,015(010)
        jrst    case_bad_v1566
        skipn   bad_v1566
        jrst    case_good_v1566
        jrst    case_bad_v1566
case_good_v1566:
        addi    010,016                ; 14 decimal words
        sojg    011,case_next_v1566
        setz    1,
        popj    17,
case_bad_v1566:
        move    1,011
        popj    17,

pipe_fifo_mount_busy:
proc_swap_mount_busy:
        jrst    kret_zero
file_mount_busy_v1523:
        move    1,owner_v1566
        popj    17,
vfs_sync:
        aos     sync_count_v1566
        move    5,mode_v1566
        caie    5,017                   ; simulated owner appeared in SYNC
        jrst    sync_return_v1566
        setom   owner_v1566
sync_return_v1566:
        skipn   sync_error_v1566
        jrst    kret_zero
        jrst    kret_neg1

; Private op 027 is the only allowed provider call for this V2 fixture.
; Normal SYNC is a separate vfs_sync native boundary above. The model
; represents exact mounted seal completion, and may fail/poison and alter
; MM/owner between the original and final VFS owner scan.
fs_provider_reg_call:
        caie    6,027
        jrst    provider_bad_v1566
        caie    7,5
        jrst    provider_bad_v1566
        caie    1,1
        jrst    provider_bad_v1566
        came    2,[050201000000]
        jrst    provider_bad_v1566
        aos     calls_v1566
        move    5,mode_v1566
        caie    5,2                     ; MM allocation failed before I/O
        jrst    provider_phys_v1566
        jrst    kret_neg1
provider_phys_v1566:
        caie    5,6                     ; RO invalid armed mount rejected
        jrst    provider_work_v1566
        jrst    kret_neg1
provider_work_v1566:
        caie    5,1                     ; interrupted physical CLEAN
        jrst    provider_success_v1566
        movei   3,0400000              ; sticky uncertainty while armed
        iorm    3,media_v1566+1
        jrst    kret_neg1
provider_success_v1566:
        caie    5,010                   ; false success keeps ARMED bit
        jrst    provider_clear_armed_v1566
        jrst    provider_new_owner_v1566
provider_clear_armed_v1566:
        movei   3,0040000              ; consumes in-RAM ARMED
        andcam  3,media_v1566+1
        caie    5,3
        jrst    provider_new_owner_v1566
        movei   3,01234                ; false successful MM cleanup
        movem   3,aux_v1566+1
provider_new_owner_v1566:
        caie    5,4
        jrst    provider_change_root_v1566
        setom   owner_v1566           ; new remote FILE owner after I/O
provider_change_root_v1566:
        caie    5,5
        jrst    provider_false_success_v1566
        setzm   roots_v1566+1          ; original published root stolen
provider_false_success_v1566:
        caie    5,7                     ; returned 0 but left WR_UNCERT
        jrst    provider_ok_v1566
        movei   3,0400000
        iorm    3,media_v1566+1
provider_ok_v1566:
        jrst    kret_zero
provider_bad_v1566:
        setom   bad_v1566
        jrst    kret_neg1
file_unlock_mount:
        caie    1,2
        jrst    provider_bad_v1566
        aos     unlocks_v1566
        jrst    kret_zero
kret_zero:
        setz    1,
        popj    17,
kret_neg1:
        seto    1,
        popj    17,

        .data
        .globl cases_v1566
        .globl case_count_v1566
kconst_1_1: .word 1,,1
kconst_2_2: .word 2,,2
kconst_3_3: .word 3,,3
vfs_mount_limit: .word 3
vfs_mount_policy: .word 0
vfs_mount_root_base: .word roots_v1566
vfs_mount_target_base: .word targets_v1566
dtfs_media_base: .word media_v1566
vfs_mount_aux_base_v1560: .word aux_v1566
vfs_namespace_root: .word 060101000003
roots_v1566:
        .word 060101000003
        .word 050201000000
        .word 0
targets_v1566:
        .word 0
        .word 060001010003
        .word 0
media_v1566: .block 3
aux_v1566: .block 3
mode_v1566: .word 0
owner_v1566: .word 0
sync_error_v1566: .word 0
calls_v1566: .word 0
sync_count_v1566: .word 0
unlocks_v1566: .word 0
bad_v1566: .word 0
        .bss
__test_exit: .block 1
