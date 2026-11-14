; Actual PDP-6 mounted DTFS SEAL helper; only pinned-MM/physical CLEAN
; completion is a strict test callback. The VFS mount owner/media/IDs,
; readonly policy and MM-retained base are actual source-linked checks.
        .text
        .globl main
        .globl dtfs_intent_mount_seal_v1566
        .globl dtfs_intent_owned_clean_v1566
        .globl vfs_mount_root_base
        .globl vfs_mount_limit
        .globl vfs_mount_policy
        .globl dtfs_media_base
        .globl vfs_mount_aux_base_v1560
        .globl tsfs_file_shape_base
        .globl tsfs_extent_media_base
        .globl __test_exit

main:
        movei   010,cases_v1566
        movei   011,case_count_v1566
case_next_v1566:
        setzm   calls_v1566
        move    1,1(010)
        movem   1,roots_v1566
        move    1,2(010)
        movem   1,roots_v1566+1
        move    1,3(010)
        movem   1,media_v1566
        move    1,4(010)
        movem   1,media_v1566+1
        move    1,5(010)
        movem   1,aux_v1566
        move    1,6(010)
        movem   1,aux_v1566+1
        move    1,7(010)
        movem   1,vfs_mount_policy
        move    1,010(010)
        movem   1,mode_v1566
        move    1,011(010)
        movem   1,missing_v1566
        move    1,012(010)
        movem   1,idhigh_v1566
        movem   1,idhigh_v1566+1
        move    1,013(010)
        movem   1,idlow_v1566
        movem   1,idlow_v1566+1
        movei   1,roots_v1566
        movem   1,vfs_mount_root_base
        movei   1,media_v1566
        movem   1,dtfs_media_base
        movei   1,aux_v1566
        movem   1,vfs_mount_aux_base_v1560
        movei   1,idhigh_v1566
        movem   1,tsfs_file_shape_base
        movei   1,idlow_v1566
        movem   1,tsfs_extent_media_base
        movei   1,2
        movem   1,vfs_mount_limit
        move    5,missing_v1566
        trnn    5,1                     ; absent root slab
        jrst    case_media_ptr_v1566
        setzm   vfs_mount_root_base
case_media_ptr_v1566:
        trnn    5,2                     ; absent media slab
        jrst    case_aux_ptr_v1566
        setzm   dtfs_media_base
case_aux_ptr_v1566:
        trnn    5,4                     ; absent MM ownership slab
        jrst    case_idhigh_ptr_v1566
        setzm   vfs_mount_aux_base_v1560
case_idhigh_ptr_v1566:
        trnn    5,010                   ; absent saved HIGH ID slab
        jrst    case_idlow_ptr_v1566
        setzm   tsfs_file_shape_base
case_idlow_ptr_v1566:
        trnn    5,020                   ; absent saved LOW ID slab
        jrst    case_limit_v1566
        setzm   tsfs_extent_media_base
case_limit_v1566:
        trnn    5,040                   ; invalid boot mount capacity
        jrst    case_call_v1566
        setzm   vfs_mount_limit
case_call_v1566:
        move    1,(010)                ; exact requested slot
        move    2,014(010)             ; exact expected root vnode
        pushj   17,dtfs_intent_mount_seal_v1566
        came    1,015(010)
        jrst    case_bad_v1566
        move    1,calls_v1566
        came    1,016(010)
        jrst    case_bad_v1566
        move    1,media_v1566
        came    1,017(010)
        jrst    case_bad_v1566
        move    1,media_v1566+1
        came    1,020(010)
        jrst    case_bad_v1566
        move    1,aux_v1566
        came    1,021(010)
        jrst    case_bad_v1566
        move    1,aux_v1566+1
        came    1,022(010)
        jrst    case_bad_v1566
        move    1,roots_v1566
        came    1,023(010)
        jrst    case_bad_v1566
        move    1,roots_v1566+1
        came    1,024(010)
        jrst    case_bad_v1566
        addi    010,025                ; 21 decimal fields
        sojg    011,case_next_v1566
        setz    1,
        popj    17,
case_bad_v1566:
        move    1,011                  ; always nonzero failing case
        popj    17,

; Native entry receives unit, both admitted ID halves, &aux[slot].
; Simulate only physical completion, not owner checks. A REAL v1552
; lease/raw write/readback is separately tested in other v1566 suites.
dtfs_intent_owned_clean_v1566:
        aos     calls_v1566
        move    6,4
        move    7,3
        move    5,2
        move    4,(6)
        jumpn   4,callback_fail_v1566  ; never overwrite MM owner
        move    4,6
        subi    4,aux_v1566
        jumpl   4,callback_fail_v1566
        caile   4,1
        jrst    callback_fail_v1566
        move    4,media_v1566(4)
        andi    4,7
        came    4,1                    ; exact physical unit
        jrst    callback_fail_v1566
        move    4,idhigh_v1566
        came    4,5
        jrst    callback_fail_v1566
        move    4,idlow_v1566
        came    4,7
        jrst    callback_fail_v1566
        move    5,mode_v1566
        caie    5,2                    ; MM allocation fails BEFORE I/O
        jrst    callback_phys_v1566
        jrst    callback_fail_v1566
callback_phys_v1566:
        ; The real pinned wrapper sets this marker BEFORE physical I/O.
        ; For mode 8, emulate a dangerous FALSE success with no marker.
        caie    5,010
        jrst    callback_mark_v1566
        jrst    callback_mode_v1566
callback_mark_v1566:
        move    4,6
        subi    4,aux_v1566
        movei   7,0400000
        iorm    7,media_v1566(4)
callback_mode_v1566:
        caie    5,1                     ; physical CLEAN failed
        jrst    callback_retain_mm_v1566
        jrst    callback_fail_v1566
callback_retain_mm_v1566:
        caie    5,3                     ; pin/free refused
        jrst    callback_change_root_v1566
        movei   7,01234
        movem   7,(6)
        jrst    callback_fail_v1566
callback_change_root_v1566:
        caie    5,4                     ; slot root mutated during I/O
        jrst    callback_change_media_v1566
        movei   7,0
        movem   7,roots_v1566(4)
callback_change_media_v1566:
        caie    5,5                     ; read-suspect after raw I/O
        jrst    callback_change_id_v1566
        movei   7,0200000
        iorm    7,media_v1566(4)
callback_change_id_v1566:
        caie    5,6                     ; saved ID altered during I/O
        jrst    callback_change_policy_v1566
        aos     idhigh_v1566(4)
callback_change_policy_v1566:
        caie    5,7                     ; unexpectedly now RO
        jrst    callback_false_mm_v1566
        movei   7,1
        lsh     7,0(4)
        iorm    7,vfs_mount_policy
callback_false_mm_v1566:
        caie    5,011                   ; MM remains owned on false success
        jrst    callback_good_v1566
        movei   7,01234
        movem   7,(6)
callback_good_v1566:
        setz    1,
        popj    17,
callback_fail_v1566:
        seto    1,
        popj    17,

        .data
        .globl cases_v1566
        .globl case_count_v1566
vfs_mount_limit: .word 2
vfs_mount_policy: .word 0
vfs_mount_root_base: .word roots_v1566
dtfs_media_base: .word media_v1566
vfs_mount_aux_base_v1560: .word aux_v1566
tsfs_file_shape_base: .word idhigh_v1566
tsfs_extent_media_base: .word idlow_v1566
roots_v1566: .block 2
media_v1566: .block 2
aux_v1566: .block 2
idhigh_v1566: .block 2
idlow_v1566: .block 2
mode_v1566: .word 0
missing_v1566: .word 0
calls_v1566: .word 0
        .bss
__test_exit: .block 1
