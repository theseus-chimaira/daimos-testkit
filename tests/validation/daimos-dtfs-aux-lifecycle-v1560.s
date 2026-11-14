; v1560: execute real VFS mount publication and final unmount gate on PDP-6.
; The native routines are extracted by the shell driver, no model rewrites.
        .text
        .globl main
        .globl __test_exit
        .globl vfs_mount_found
        .globl vfs_unmount_after_prepare
        .globl vfs_dtfs_aux_empty_v1560
        .globl vfs_mount_aux_base_v1560
        .globl vfs_mount_limit
        .globl vfs_mount_target_base
        .globl vfs_mount_root_base
        .globl vfs_mount_policy
        .globl vfs_namespace_root
        .globl vfs_unmount_owner_check_v1523
        .globl file_unlock_mount
        .globl vfs_mount_retire_slot
        .globl kret_zero
        .globl kret_neg1
        .globl kconst_2_2

main:
        movei   010,cases_v1560
        movei   011,case_count_v1560
next_case_v1560:
        setzm   root_v1560
        setzm   root_v1560+1
        setzm   target_v1560
        setzm   target_v1560+1
        setzm   vfs_mount_policy
        setzm   root_result_v1560
        setzm   unlock_count_v1560
        setzm   retire_count_v1560
        move    1,3(010)
        movem   1,aux_v1560
        move    1,4(010)
        movem   1,aux_v1560+1
        move    1,5(010)
        cain    1,1
        jrst    no_aux_v1560
        movei   1,aux_v1560
        movem   1,vfs_mount_aux_base_v1560
        jrst    slot_ready_v1560
no_aux_v1560:
        setzm   vfs_mount_aux_base_v1560
slot_ready_v1560:
        move    7,2(010)               ; selected zero-based slot
        move    5,(010)                ; operation 0 mount, 1 unmount
        jumpe   5,mount_case_v1560

        ; Simulate VFS after successful synchronous SYNC and PREPARE.
        ; The original VFS routine is entered by a JRST, with root and
        ; slot already saved on the process stack below the caller frame.
        move    4,1(010)               ; selected existing provider
        lsh     4,036
        movei   3,1(7)
        lsh     3,6
        iori    3,1                     ; KIND_ROOT 1
        lsh     3,022
        ior     4,3
        move    3,7
        add     3,[root_v1560]
        movem   4,(3)
        movei   1,010777
        move    1,4                     ; exact root
        move    2,7                     ; zero-based slot
        pushj   17,unmount_wrapper_v1560
        jrst    case_check_v1560
unmount_wrapper_v1560:
        push    17,1                    ; root above caller's return
        push    17,2                    ; slot above root
        jrst    vfs_unmount_after_prepare

mount_case_v1560:
        ; An ordinary prevalidated VFS call has already found this slot.
        movei   1,010777               ; target vnode
        move    2,1(010)               ; requested provider
        movei   3,1                     ; root kind
        setz    4,                      ; provider object index
        push    17,[root_result_v1560] ; sixth C argument: rootp
        push    17,[1]                 ; fifth C argument: READ-ONLY
        pushj   17,vfs_mount_found
        sub     17,[2,,2]

case_check_v1560:
        came    1,6(010)
        jrst    bad_v1560
        move    2,unlock_count_v1560
        came    2,7(010)
        jrst    bad_v1560
        move    2,retire_count_v1560
        came    2,010(010)
        jrst    bad_v1560
        move    2,aux_v1560
        came    2,3(010)
        jrst    bad_v1560
        move    2,aux_v1560+1
        came    2,4(010)
        jrst    bad_v1560
        move    2,2(010)
        add     2,[root_v1560]
        move    3,(2)
        move    4,011(010)             ; expected published root status
        jumpe   4,case_expect_retired_v1560
        skipn   3
        jrst    bad_v1560
        jrst    case_done_v1560
case_expect_retired_v1560:
        skipn   3
        jrst    case_done_v1560
        jrst    bad_v1560
case_done_v1560:
        addi    010,012                ; 10 words/case
        sojg    011,next_case_v1560
        setz    1,
        popj    17,
bad_v1560:
        move    1,011
        popj    17,

vfs_unmount_owner_check_v1523:
        movei   2,1(7)
        came    1,2
        jrst    kret_neg1
        jrst    kret_zero
file_unlock_mount:
        aos     unlock_count_v1560
        jrst    kret_zero
vfs_mount_retire_slot:
        aos     retire_count_v1560
        move    3,2
        add     3,[root_v1560]
        setzm   (3)
        jrst    kret_zero
kret_zero:
        setz    1,
        popj    17,
kret_neg1:
        seto    1,
        popj    17,

        .data
        .globl cases_v1560
        .globl case_count_v1560
kconst_2_2: .word 0000002000002
vfs_mount_target_base: .word target_v1560
vfs_mount_root_base: .word root_v1560
vfs_mount_aux_base_v1560: .word aux_v1560
vfs_mount_limit: .word 2
vfs_mount_policy: .word 0
vfs_namespace_root: .word 070101000000
root_result_v1560: .word 0
target_v1560: .block 2
root_v1560: .block 2
aux_v1560: .block 2
unlock_count_v1560: .word 0
retire_count_v1560: .word 0
        .bss
__test_exit: .block 1
