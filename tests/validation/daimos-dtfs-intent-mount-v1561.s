; v1561: real PDP-6 physical-unit -> mounted V2 intent/owner bridge.
; Only v1553's already-tested physical/MM service is a strict oracle.
        .text
        .globl main
        .globl __test_exit
        .globl dtfs_intent_mount_gate_v1561
        .globl dtfs_intent_first_write_v1553
        .globl vfs_mount_root_base
        .globl dtfs_media_base
        .globl vfs_mount_aux_base_v1560
        .globl vfs_mount_policy
        .globl vfs_mount_limit

main:
        movei   010,cases_v1561
        movei   011,case_count_v1561
case_next_v1561:
        move    4,1(010)
        movem   4,roots_v1561
        move    4,2(010)
        movem   4,media_v1561
        move    4,3(010)
        movem   4,roots_v1561+1
        move    4,4(010)
        movem   4,media_v1561+1
        move    4,5(010)
        movem   4,aux_v1561
        move    4,6(010)
        movem   4,aux_v1561+1
        move    4,7(010)
        movem   4,vfs_mount_policy
        movei   4,2
        movem   4,vfs_mount_limit
        movei   4,roots_v1561
        movem   4,vfs_mount_root_base
        movei   4,media_v1561
        movem   4,dtfs_media_base
        movei   4,aux_v1561
        movem   4,vfs_mount_aux_base_v1560
        move    4,010(010)             ; missing table selector
        cain    4,1
        setzm   vfs_mount_root_base
        cain    4,2
        setzm   dtfs_media_base
        cain    4,3
        setzm   vfs_mount_aux_base_v1560
        cain    4,4
        setzm   vfs_mount_limit
        move    4,011(010)             ; simulated physical service result
        movem   4,mode_v1561
        setzm   calls_v1561
        ; The real bridge uses AC10 internally across its call, restoring
        ; the caller's AC10 only on return. A lower-service test oracle
        ; must not read the caller's volatile AC10 as a case pointer.
        movem   010,case_ptr_v1561
        move    1,(010)
        pushj   17,dtfs_intent_mount_gate_v1561
        came    1,012(010)
        jrst    bad_return_v1561
        move    4,calls_v1561
        came    4,013(010)
        jrst    bad_calls_v1561
        move    4,roots_v1561
        came    4,014(010)
        jrst    bad_v1561
        move    4,media_v1561
        came    4,015(010)
        jrst    bad_v1561
        move    4,roots_v1561+1
        came    4,016(010)
        jrst    bad_v1561
        move    4,media_v1561+1
        came    4,017(010)
        jrst    bad_v1561
        move    4,aux_v1561
        came    4,020(010)
        jrst    bad_v1561
        move    4,aux_v1561+1
        came    4,021(010)
        jrst    bad_v1561
        move    4,vfs_mount_policy
        came    4,022(010)
        jrst    bad_v1561
        addi    010,024                 ; twenty words per test case
        sojg    011,case_next_v1561
        setz    1,
        popj    17,
bad_v1561:
        move    1,011                   ; failing native case index
        popj    17,
bad_return_v1561:
        movei   1,0100
        add     1,011
        popj    17,
bad_calls_v1561:
        movei   1,0200
        add     1,011
        popj    17,

; Stub only the independently proven lower v1553/v1552/v1551/v1554
; hardware/MM layers, never the production v1561 mount/owner bridge.
; This explicitly validates the exact slot and retained basep pointer.
dtfs_intent_first_write_v1553:
        aos     calls_v1561
        move    4,case_ptr_v1561
        move    4,023(4)               ; expected exact V2 slot
        came    1,4
        jrst    lower_error_v1561
        movei   5,aux_v1561
        add     5,1
        came    2,5
        jrst    lower_error_v1561
        move    6,mode_v1561
        cain    6,1                     ; lower hardware/validation error
        jrst    lower_error_v1561
        cain    6,2                     ; MM cleanup failed, base retained
        jrst    lower_leak_fail_v1561
        movei   7,0040000
        movei   4,media_v1561
        add     4,1
        iorm    7,(4)                   ; confirmed physical intent arm
        cain    6,3                     ; mount replaced during sleep
        jrst    lower_change_root_v1561
        cain    6,4                     ; media status changed during I/O
        jrst    lower_change_media_v1561
        cain    6,5                     ; VFS switched back to RO
        jrst    lower_change_policy_v1561
        cain    6,6                     ; leaked owner but false success
        jrst    lower_leak_success_v1561
        setz    1,
        popj    17,
lower_change_root_v1561:
        movei   4,roots_v1561
        add     4,1
        move    7,[060101000000]
        movem   7,(4)
        jrst    lower_success_v1561
lower_change_media_v1561:
        movei   7,0400000
        iorm    7,(4)
        jrst    lower_success_v1561
lower_change_policy_v1561:
        movei   7,1
        lsh     7,0(1)
        iorm    7,vfs_mount_policy
        jrst    lower_success_v1561
lower_leak_success_v1561:
        movei   7,07777
        movem   7,(5)
lower_success_v1561:
        setz    1,
        popj    17,
lower_leak_fail_v1561:
        movei   7,07777
        movem   7,(5)
lower_error_v1561:
        seto    1,
        popj    17,

        .data
vfs_mount_root_base: .word roots_v1561
dtfs_media_base: .word media_v1561
vfs_mount_aux_base_v1560: .word aux_v1561
vfs_mount_limit: .word 2
vfs_mount_policy: .word 0
roots_v1561: .block 2
media_v1561: .block 2
aux_v1561: .block 2
mode_v1561: .word 0
calls_v1561: .word 0
case_ptr_v1561: .word 0
        .globl cases_v1561
        .globl case_count_v1561
        .bss
__test_exit: .block 1
