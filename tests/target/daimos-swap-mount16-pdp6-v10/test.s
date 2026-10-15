; Exercise the production one-word PURE backing unpacker at mount ID 16.
; The test intentionally uses maximum text bits and a distinct odd provider.
        .text
        .globl main
main:
        movei   3,7                       ; TSFS provider, odd local kind
        lsh     3,036
        movem   3,vfs_mount_root+017      ; slot 15 = public mount ID 16

        movei   1,012345                 ; full 18-bit vnode index domain
        movei   3,017                    ; 4-bit zero-based mount slot
        lsh     3,022
        ior     1,3
        movei   3,037777                 ; maximal 14-bit PURE text span
        lsh     3,026
        ior     1,3
        movem   1,test_record
        pushj   17,proc_swap_unpack_backing
        jumpe   1,test_fail
        caie    2,037777
        jrst    test_fail
        ldb     3,[POINT 6,1,5]         ; restored provider
        caie    3,7
        jrst    test_fail
        ldb     3,[POINT 6,1,11]        ; restored public mount ID
        caie    3,020
        jrst    test_fail
        ldb     3,[POINT 6,1,17]        ; provider-local kind
        caie    3,2
        jrst    test_fail
        hrrz    3,1
        caie    3,012345
        jrst    test_fail

        ; Once its volume is unavailable, PURE backing reconstruction fails
        ; without manufacturing an invalid provider or returning text words.
        setzm   vfs_mount_root+017
        move    1,test_record
        pushj   17,proc_swap_unpack_backing
        jumpn   1,test_fail
        jumpn   2,test_fail
        setz    1,
        popj    17,
test_fail:
        movei   1,1
        popj    17,

        .bss
        .globl  vfs_mount_root
vfs_mount_root:
        .block  020
test_record:
        .block  1
        .globl  __test_exit
__test_exit:
        .block  1
