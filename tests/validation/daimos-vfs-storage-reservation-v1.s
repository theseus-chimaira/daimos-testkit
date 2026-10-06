        .text
        .globl  main
        .globl  kret_neg1
        .globl  kret_zero
        .globl  vfs_stat
        .globl  pipe_fifo_mount_busy
        .globl  proc_swap_mount_busy
        .globl  proc_swap_backing_busy
        .globl  vfs_sync
        .globl  fs_provider_reg_call
        .globl  file_unlock_mount
        .globl  vfs_namespace_root
        .globl  vfs_mount_target
        .globl  vfs_mount_root
        .globl  vfs_mount_ro
        .globl  __test_exit
        .globl  kconst_2_2
        .globl  kconst_7_7
        .globl  kconst_13_13

; Exercise production vfs_mount(), vfs_storage_release(), and vfs_unmount().
; Flags: RDONLY=1, SWAP=020, LOGSTORE=0400.
main:
        ; Root mount owns both reservation types.
        setz    1,
        movei   2,6
        movei   3,1
        setz    4,
        movei   5,0420
        movei   6,root1
        push    17,6
        push    17,5
        pushj   17,vfs_mount
        sub     17,[2,,2]
        jumpn   1,test_fail
        skipn   root1
        jrst    test_fail
        move    7,vfs_mount_ro
        andi    7,0420
        caie    7,0420
        jrst    test_fail

        ; Another mount cannot steal swap while mount 1 owns it.
        movei   1,0111
        movei   2,6
        movei   3,1
        setz    4,
        movei   5,020
        movei   6,root2
        push    17,6
        push    17,5
        pushj   17,vfs_mount
        sub     17,[2,,2]
        jumpge  1,test_fail

        ; Releasing only swap leaves logstore ownership on mount 1.
        movei   1,1
        movei   2,020
        pushj   17,vfs_storage_release
        jumpn   1,test_fail
        move    7,vfs_mount_ro
        trne    7,020
        jrst    test_fail
        trnn    7,0400
        jrst    test_fail
        move    1,root1
        pushj   17,vfs_unmount
        jumpge  1,test_fail

        ; Mount 2 may now acquire swap without disturbing mount 1 logstore.
        movei   1,0111
        movei   2,6
        movei   3,1
        setz    4,
        movei   5,020
        movei   6,root2
        push    17,6
        push    17,5
        pushj   17,vfs_mount
        sub     17,[2,,2]
        jumpn   1,test_fail
        skipn   root2
        jrst    test_fail
        move    7,vfs_mount_ro
        andi    7,0440
        caie    7,0440               ; slot0 log=0400, slot1 swap=040
        jrst    test_fail

        ; Mount 2 remains pinned until its swap reservation is released.
        move    1,root2
        pushj   17,vfs_unmount
        jumpge  1,test_fail
        movei   1,2
        movei   2,020
        pushj   17,vfs_storage_release
        jumpn   1,test_fail
        move    1,root2
        pushj   17,vfs_unmount
        jumpn   1,test_fail

        ; Mount 1 is still independently pinned by logstore.
        move    1,root1
        pushj   17,vfs_unmount
        jumpge  1,test_fail
        movei   1,1
        movei   2,0400
        pushj   17,vfs_storage_release
        jumpn   1,test_fail
        move    1,root1
        pushj   17,vfs_unmount
        jumpn   1,test_fail

        setz    1,
        popj    17,

test_fail:
        movei   1,1
        popj    17,

kret_neg1:
        seto    1,
        popj    17,
kret_zero:
        setz    1,
        popj    17,

; Every non-root mount target used by the oracle is a directory.
vfs_stat:
        movei   3,1
        movem   3,(2)
        setz    1,
        popj    17,

pipe_fifo_mount_busy:
proc_swap_mount_busy:
proc_swap_backing_busy:
        setz    1,
        popj    17,
vfs_sync:
        setz    1,
        popj    17,
fs_provider_reg_call:
        setz    1,
        popj    17,
file_unlock_mount:
        setz    1,
        popj    17,

        .bss
vfs_namespace_root:
        .block  1
vfs_mount_target:
        .block  4
vfs_mount_root:
        .block  4
vfs_mount_ro:
        .block  1
root1:
        .block  1
root2:
        .block  1
__test_exit:
        .block  1

        .data
kconst_7_7:
        .word   7,,7
kconst_2_2:
        .word   2,,2
kconst_13_13:
        .word   013,,013
