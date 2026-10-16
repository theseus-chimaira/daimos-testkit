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
        .globl  v12_mount_target
        .globl  v12_mount_root
        .globl  vfs_mount_policy
        .globl  vfs_mount_limit
        .globl  __test_exit
        .globl  kconst_2_2
        .globl  kconst_7_7
        .globl  kconst_13_13

; Exercise production vfs_mount(), vfs_storage_release(), and vfs_unmount().
; The last phase tests mount-slot retirement and reuse of the former root
; slot, including reinitialization of its read-only policy.
; Flags: RDONLY=1, SWAP=020, LOGSTORE=0400.
main:
        ; KINIT-style publication: switch both bases before mounting root.
        ; Poison the fallback table to catch accidental direct references.
        movei   0,0123456
        movem   0,fallback_target
        movem   0,fallback_root
        movei   0,v12_mount_target
        movem   0,vfs_mount_target_base
        movei   0,v12_mount_root
        movem   0,vfs_mount_root_base
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
        ldb     7,[POINT 5,vfs_mount_policy,9] ; SWAP owner
        caie    7,1
        jrst    test_fail
        ldb     7,[POINT 5,vfs_mount_policy,4] ; LOGSTORE owner
        caie    7,1
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
        ldb     7,[POINT 5,vfs_mount_policy,9]
        jumpn   7,test_fail
        ldb     7,[POINT 5,vfs_mount_policy,4]
        caie    7,1
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
        ldb     7,[POINT 5,vfs_mount_policy,9]
        caie    7,2                    ; SWAP owned by mount ID 2
        jrst    test_fail
        ldb     7,[POINT 5,vfs_mount_policy,4]
        caie    7,1                    ; LOGSTORE remains mount ID 1
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

        ; The mount mutation leaf must retire both namespace tables and
        ; every policy bit; no stale mount state may survive slot reuse.
        skipe   v12_mount_root
        jrst    test_fail
        skipe   v12_mount_target
        jrst    test_fail
        skipe   vfs_mount_policy
        jrst    test_fail

        ; Reuse the now-free root mount slot with read-only policy.
        setz    1,
        movei   2,6
        movei   3,1
        setz    4,
        movei   5,1
        movei   6,root3
        push    17,6
        push    17,5
        pushj   17,vfs_mount
        sub     17,[2,,2]
        jumpn   1,test_fail
        move    7,v12_mount_root
        came    7,root3
        jrst    test_fail
        move    7,vfs_mount_policy
        andi    7,1
        caie    7,1
        jrst    test_fail

        move    1,root3
        pushj   17,vfs_unmount
        jumpn   1,test_fail
        skipe   v12_mount_root
        jrst    test_fail
        skipe   v12_mount_target
        jrst    test_fail
        skipe   vfs_mount_policy
        jrst    test_fail

        move    0,fallback_target
        caie    0,0123456
        jrst    test_fail
        move    0,fallback_root
        caie    0,0123456
        jrst    test_fail
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
v12_mount_target:
        .block  4
v12_mount_root:
        .block  4
fallback_target:
        .block  4
fallback_root:
        .block  4
vfs_mount_policy:
        .block  1
root1:
        .block  1
root2:
        .block  1
root3:
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
        .globl  vfs_mount_target_base
        .globl  vfs_mount_root_base
vfs_mount_target_base:
        .word   fallback_target
vfs_mount_root_base:
        .word   fallback_root
vfs_mount_limit:
        .word   4
