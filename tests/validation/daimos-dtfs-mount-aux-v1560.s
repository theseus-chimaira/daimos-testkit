; v1560 PDP-6: production per-mount provider-private owner guard.
; The true helper instructions are linked by the shell driver.
        .text
        .globl main
        .globl __test_exit
        .globl vfs_dtfs_aux_empty_v1560
        .globl vfs_mount_aux_base_v1560
        .globl vfs_mount_limit
        .globl kret_zero
        .globl kret_neg1

main:
        movei   010,cases_v1560
        movei   011,case_count_v1560
case_loop_v1560:
        move    1,1(010)
        movem   1,aux_mount_v1560
        move    1,2(010)
        movem   1,aux_mount_v1560+1
        move    1,3(010)
        movem   1,vfs_mount_limit
        movei   1,aux_mount_v1560
        skipn   4,4(010)               ; 1: published mount slab absent
        movem   1,vfs_mount_aux_base_v1560
        skipe   4,4(010)
        setzm   vfs_mount_aux_base_v1560
        move    1,(010)                ; exact zero-based slot
        movei   2,01234                ; preserved caller registers
        movei   3,02345
        movei   4,03456
        movei   5,04567
        movei   7,06701
        pushj   17,vfs_dtfs_aux_empty_v1560
        came    1,5(010)
        jrst    bad_v1560
        caie    2,01234
        jrst    bad_v1560
        caie    3,02345
        jrst    bad_v1560
        caie    4,03456
        jrst    bad_v1560
        caie    5,04567
        jrst    bad_v1560
        caie    7,06701
        jrst    bad_v1560
        move    1,aux_mount_v1560
        came    1,1(010)
        jrst    bad_v1560
        move    1,aux_mount_v1560+1
        came    1,2(010)
        jrst    bad_v1560
        addi    010,6
        sojg    011,case_loop_v1560
        setz    1,
        popj    17,
bad_v1560:
        move    1,011                  ; nonzero failing native case
        popj    17,

kret_zero:
        setz    1,
        popj    17,
kret_neg1:
        seto    1,
        popj    17,

        .data
vfs_mount_aux_base_v1560: .word aux_mount_v1560
vfs_mount_limit: .word 2
aux_mount_v1560: .block 2
        .globl cases_v1560
        .globl case_count_v1560
        .bss
__test_exit: .block 1
