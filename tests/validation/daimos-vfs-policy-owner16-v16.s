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
        movei   0,1
        movem   0,v16_stage
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
        ldb     7,[POINT 5,vfs_mount_policy,19] ; SWAP owner
        caie    7,1
        jrst    test_fail
        ldb     7,[POINT 5,vfs_mount_policy,14] ; LOGSTORE owner
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
        ldb     7,[POINT 5,vfs_mount_policy,19]
        jumpn   7,test_fail
        ldb     7,[POINT 5,vfs_mount_policy,14]
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
        ldb     7,[POINT 5,vfs_mount_policy,19]
        caie    7,2                    ; SWAP owned by mount ID 2
        jrst    test_fail
        ldb     7,[POINT 5,vfs_mount_policy,14]
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
        skipe   vfs_mount_root
        jrst    test_fail
        skipe   vfs_mount_target
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
        move    7,vfs_mount_root
        came    7,root3
        jrst    test_fail
        move    7,vfs_mount_policy
        andi    7,1
        caie    7,1
        jrst    test_fail

        move    1,root3
        pushj   17,vfs_unmount
        jumpn   1,test_fail
        skipe   vfs_mount_root
        jrst    test_fail
        skipe   vfs_mount_target
        jrst    test_fail
        skipe   vfs_mount_policy
        jrst    test_fail

        ; Reserve fifteen dummy occupied slots to force the final one-word
        ; policy fields to represent public mount ID 16 (octal 020).
        movei   0,2
        movem   0,v16_stage
        movei   0,020
        movem   0,vfs_mount_limit
        setz    6,
v16_fill_slots:
        movei   5,1
        movem   5,vfs_mount_root(6)
        movei   5,020000
        add     5,6
        movem   5,vfs_mount_target(6) ; distinct occupied target per slot
        addi    6,1
        caige   6,017
        jrst    v16_fill_slots
        movei   0,020
        movem   0,v16_stage
        skipe   vfs_namespace_root
        jrst    test_fail
        movei   0,021
        movem   0,v16_stage

        ; Mount slot 15 with both exclusive owners and read-only policy.
        setz    1,
        movei   2,6
        movei   3,1
        setz    4,
        movei   5,0421
        movei   6,root16
        push    17,6
        push    17,5
        pushj   17,vfs_mount
        sub     17,[2,,2]
        jumpn   1,test_fail
        movei   0,3
        movem   0,v16_stage
        move    7,vfs_mount_root+017
        came    7,root16
        jrst    test_fail
        movei   6,1
        lsh     6,017
        tdnn    6,vfs_mount_policy      ; RO flag of slot 15
        jrst    test_fail
        ldb     7,[POINT 5,vfs_mount_policy,19]
        caie    7,020                   ; SWAP owner public ID 16
        jrst    test_fail
        ldb     7,[POINT 5,vfs_mount_policy,14]
        caie    7,020                   ; LOGSTORE owner public ID 16
        jrst    test_fail
        move    1,root16
        pushj   17,vfs_readonly
        caie    1,1                     ; read-only lookup works at slot 15
        jrst    test_fail
        movei   0,4
        movem   0,v16_stage

        ; Invalid release cannot steal another mount's reservations.
        movei   1,017
        movei   2,0420
        pushj   17,vfs_storage_release
        jumpge  1,test_fail
        ldb     7,[POINT 5,vfs_mount_policy,19]
        caie    7,020
        jrst    test_fail
        movei   0,5
        movem   0,v16_stage

        ; Legitimate release clears both owners, but retains RO until
        ; unmount retires the slot.
        movei   1,020
        movei   2,0420
        pushj   17,vfs_storage_release
        jumpn   1,test_fail
        ldb     7,[POINT 5,vfs_mount_policy,19]
        jumpn   7,test_fail
        ldb     7,[POINT 5,vfs_mount_policy,14]
        jumpn   7,test_fail
        tdnn    6,vfs_mount_policy
        jrst    test_fail
        move    1,root16
        pushj   17,vfs_readonly
        caie    1,1
        jrst    test_fail
        movei   0,6
        movem   0,v16_stage
        move    1,root16
        pushj   17,vfs_unmount
        jumpn   1,test_fail
        skipe   vfs_mount_root+017
        jrst    test_fail
        skipe   vfs_mount_target+017
        jrst    test_fail
        skipe   vfs_mount_policy
        jrst    test_fail
        move    1,root16
        pushj   17,vfs_readonly
        jumpn   1,test_fail

        setz    1,
        popj    17,

test_fail:
        move    1,v16_stage
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
        .block  020
vfs_mount_root:
        .block  020
vfs_mount_policy:
        .block  1
root1:
        .block  1
root2:
        .block  1
root3:
        .block  1
root16:
        .block  1
v16_stage:
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
        .word   vfs_mount_target
vfs_mount_root_base:
        .word   vfs_mount_root
vfs_mount_limit:
        .word   4
