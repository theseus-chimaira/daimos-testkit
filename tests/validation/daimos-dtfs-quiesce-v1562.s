; Native PDP-6 v1562 VFS DTFS quiescence and owner-admission tests.
; The shell driver links the actual production helpers, not a reimplementation.
        .text
        .globl main
        .globl __test_exit
        .globl vfs_dtfs_owner_admit_v1562
        .globl vfs_dtfs_quiesce_begin_v1562
        .globl vfs_dtfs_quiesce_end_v1562
        .globl vfs_mount_root_base
        .globl dtfs_media_base
        .globl vfs_mount_aux_base_v1560
        .globl vfs_mount_limit
        .globl kret_zero
        .globl kret_neg1
        .globl kconst_1_1

main:
        movei   010,cases_v1562
        movei   011,case_count_v1562
case_loop_v1562:
        move    1,2(010)
        movem   1,roots_v1562
        move    1,3(010)
        movem   1,roots_v1562+1
        move    1,4(010)
        movem   1,media_v1562
        move    1,5(010)
        movem   1,media_v1562+1
        move    1,6(010)
        movem   1,aux_v1562
        move    1,7(010)
        movem   1,aux_v1562+1
        move    1,010(010)
        movem   1,vfs_mount_limit
        movei   1,roots_v1562
        movem   1,vfs_mount_root_base
        movei   1,media_v1562
        movem   1,dtfs_media_base
        movei   1,aux_v1562
        movem   1,vfs_mount_aux_base_v1560
        move    012,011(010)           ; missing pointers / wrong original root
        trne    012,1
        setzm   vfs_mount_root_base
        trne    012,2
        setzm   dtfs_media_base
        trne    012,4
        setzm   vfs_mount_aux_base_v1560
        move    1,1(010)               ; raw vnode or zero-based slot
        move    2,roots_v1562
        skipn   (010)                   ; mode 0 uses a vnode, not slot
        jrst    case_root_ready_v1562
        move    3,1(010)
        caie    3,1
        jrst    case_root_ready_v1562
        move    2,roots_v1562+1
case_root_ready_v1562:
        trne    012,010                ; deliberately wrong expected root
        movei   2,077777
        movei   3,02345
        movei   4,03456
        movei   5,04567
        movei   6,05670
        movei   7,06701
        move    013,(010)              ; mode 0=admit,1=begin,2=end
        jumpe   013,case_admit_v1562
        caie    013,1
        jrst    case_end_v1562
        pushj   17,vfs_dtfs_quiesce_begin_v1562
        jrst    case_return_v1562
case_end_v1562:
        pushj   17,vfs_dtfs_quiesce_end_v1562
        jrst    case_return_v1562
case_admit_v1562:
        pushj   17,vfs_dtfs_owner_admit_v1562
case_return_v1562:
        came    1,012(010)
        jrst    case_bad_return_v1562
        move    1,roots_v1562
        skipn   (010)
        jrst    case_expected_root_v1562
        move    0,1(010)
        caie    0,1
        jrst    case_expected_root_v1562
        move    1,roots_v1562+1
case_expected_root_v1562:
        trne    012,010
        movei   1,077777
        came    2,1
        jrst    case_bad_v1562
        caie    3,02345
        jrst    case_bad_v1562
        caie    4,03456
        jrst    case_bad_v1562
        caie    5,04567
        jrst    case_bad_v1562
        caie    6,05670
        jrst    case_bad_v1562
        caie    7,06701
        jrst    case_bad_v1562
        move    1,media_v1562
        came    1,013(010)
        jrst    case_bad_media_v1562
        move    1,media_v1562+1
        came    1,014(010)
        jrst    case_bad_media_v1562
        move    1,aux_v1562
        came    1,6(010)
        jrst    case_bad_v1562
        move    1,aux_v1562+1
        came    1,7(010)
        jrst    case_bad_v1562
        addi    010,015                ; 13 decimal words/case
        sojg    011,case_loop_v1562
        setz    1,
        popj    17,
case_bad_v1562:
        move    1,011
        popj    17,
case_bad_return_v1562:
        move    1,011
        iori    1,01000
        popj    17,
case_bad_media_v1562:
        move    1,011
        iori    1,02000
        popj    17,

kret_zero:
        setz    1,
        popj    17,
kret_neg1:
        seto    1,
        popj    17,

        .data
vfs_mount_root_base: .word roots_v1562
dtfs_media_base: .word media_v1562
vfs_mount_aux_base_v1560: .word aux_v1562
vfs_mount_limit: .word 2
kconst_1_1: .word 1,,1
roots_v1562: .block 2
media_v1562: .block 2
aux_v1562: .block 2
        .globl cases_v1562
        .globl case_count_v1562
        .bss
__test_exit: .block 1
