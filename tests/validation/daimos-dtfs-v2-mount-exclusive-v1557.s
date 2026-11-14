; Native PDP-6 v1557: physically unique DTFS ownership when V2 involved.
; Real production source, not a model. RO and RW candidate identity use
; the same mount-unit test before publishing any physical DTC slot.
        .text
        .globl main
        .globl __test_exit
        .globl dtfs_v2_mount_exclusive_v1557
        .globl vfs_mount_root_base
        .globl vfs_mount_limit
        .globl dtfs_media_base

main:
        movei   010,cases_v1557
        movei   011,case_count_v1557
next_v1557:
        move    4,2(010)
        movem   4,root_v1557
        move    4,3(010)
        movem   4,media_v1557
        move    4,4(010)
        movem   4,root_v1557+1
        move    4,5(010)
        movem   4,media_v1557+1
        movei   4,2
        movem   4,vfs_mount_limit
        movei   4,root_v1557
        movem   4,vfs_mount_root_base
        movei   4,media_v1557
        movem   4,dtfs_media_base
        move    4,7(010)
        cain    4,1                    ; missing root-base pointer
        setzm   vfs_mount_root_base
        cain    4,2                    ; missing media-base pointer
        setzm   dtfs_media_base
        cain    4,3                    ; no published mount capacity
        setzm   vfs_mount_limit

        move    1,(010)                ; physical unit under test
        move    2,1(010)               ; 1=V2, 0=V1/legacy
        pushj   17,dtfs_v2_mount_exclusive_v1557
        came    1,6(010)
        jrst    bad_return_v1557
        ; Do not mutate the published mount tables during preflight.
        move    4,root_v1557
        came    4,2(010)
        jrst    bad_v1557
        move    4,media_v1557
        came    4,3(010)
        jrst    bad_v1557
        move    4,root_v1557+1
        came    4,4(010)
        jrst    bad_v1557
        move    4,media_v1557+1
        came    4,5(010)
        jrst    bad_v1557
        addi    010,010                ; 8 octal words/case
        sojg    011,next_v1557
        setz    1,
        popj    17,
bad_v1557:
        move    1,011                  ; nonzero state failure index
        popj    17,
bad_return_v1557:
        movei   1,0200                 ; distinguish return mismatch
        add     1,011
        popj    17,

        .data
vfs_mount_root_base: .word root_v1557
dtfs_media_base: .word media_v1557
vfs_mount_limit: .word 2
root_v1557: .block 2
media_v1557: .block 2
        .globl cases_v1557
        .globl case_count_v1557
        .bss
__test_exit: .block 1
