; v1566 DISPOSABLE GUEST INSTRUMENTATION ONLY.
;
; The production v1555 DTVOL2 READ-ONLY admission/write veto MUST NOT be
; weakened. A real physically mounted CLEAN V2 is armed through the
; already-linked v1552/1551 physical DIRTY transaction *from this
; test-only MRES entry*, after the real v1562 VFS seal is acquired.
; ONLY after verified physical DIRTY and full MM release does this test
; entry mark volatile ARMED and temporarily clear the VFS RO bit.
; Thereafter the UNMODIFIED production v1566 VFS -> DTFS CLEAN code
; must physically read DIRTY, write CLEAN, reread and retire safely.
;
; This file is appended ONLY to a copied KCORE MRES assembly file, and
; the private op 030 is added ONLY to its copied test dispatch. Never
; link this file into the production DAIMOS kernel or expose that op.

        .text
        .globl dtfs_test_physical_arm_v1566
        .globl dtfs_intent_owned_arm_v1552
        .globl vfs_mount_root_base
        .globl vfs_mount_limit
        .globl vfs_mount_policy
        .globl dtfs_media_base
        .globl vfs_mount_aux_base_v1560
        .globl tsfs_file_shape_base
        .globl tsfs_extent_media_base

dtfs_test_physical_arm_v1566:
        push    17,010
        push    17,011
        push    17,012
        push    17,013
        push    17,014
        push    17,015
        push    17,016
        move    010,1
        move    011,2                   ; original vnode
        caie    010,1                   ; ONLY disposable secondary slot1
        jrst    test_arm_refuse_v1566
        caml    010,vfs_mount_limit
        jrst    test_arm_refuse_v1566
        move    1,vfs_mount_root_base
        jumpe   1,test_arm_refuse_v1566
        add     1,010
        move    3,(1)
        came    3,011
        jrst    test_arm_refuse_v1566
        ldb     4,[POINT 6,3,5]
        caie    4,5
        jrst    test_arm_refuse_v1566
        ldb     4,[POINT 6,3,11]
        caie    4,2                     ; exact public slot2
        jrst    test_arm_refuse_v1566

        move    012,dtfs_media_base
        jumpe   012,test_arm_refuse_v1566
        add     012,010
        move    013,(012)
        trnn    013,0100000            ; native DTVOL2/CLEAN only
        jrst    test_arm_refuse_v1566
        trnn    013,0020000            ; production VFS seal is held
        jrst    test_arm_refuse_v1566
        trne    013,0640030            ; no previous arm/IO fault/foreign
        jrst    test_arm_refuse_v1566
        move    1,013
        andi    1,7
        caie    1,3                     ; disposable physical DTC3 ONLY
        jrst    test_arm_refuse_v1566
        move    1,vfs_mount_policy
        trnn    1,2                     ; must START explicitly read-only
        jrst    test_arm_refuse_v1566
        move    014,vfs_mount_aux_base_v1560
        jumpe   014,test_arm_refuse_v1566
        add     014,010
        skipn   (014)
        jrst    test_arm_id_v1566
        jrst    test_arm_refuse_v1566
test_arm_id_v1566:
        move    1,tsfs_file_shape_base
        jumpe   1,test_arm_refuse_v1566
        add     1,010
        move    015,(1)
        jumpe   015,test_arm_refuse_v1566
        move    1,tsfs_extent_media_base
        jumpe   1,test_arm_refuse_v1566
        add     1,010
        move    016,(1)
        jumpe   016,test_arm_refuse_v1566

        movei   1,3                     ; actual Type-551 DTC3 unit
        move    2,015                   ; saved high 36-bit ID
        move    3,016                   ; saved low 36-bit ID
        move    4,014                   ; exact MM-backed &aux[slot]
        pushj   17,dtfs_intent_owned_arm_v1552
        jumpn   1,test_arm_refuse_v1566

        ; The real physical DIRTY write/readback and MM unpin/free
        ; happened above. Confirm exact original mount metadata again.
        skipn   (014)
        jrst    test_arm_post_v1566
        jrst    test_arm_refuse_v1566
test_arm_post_v1566:
        move    1,vfs_mount_root_base
        jumpe   1,test_arm_refuse_v1566
        add     1,010
        move    2,(1)
        came    2,011
        jrst    test_arm_refuse_v1566
        move    1,(012)
        came    1,013
        jrst    test_arm_refuse_v1566
        move    1,tsfs_file_shape_base
        jumpe   1,test_arm_refuse_v1566
        add     1,010
        move    2,(1)
        came    2,015
        jrst    test_arm_refuse_v1566
        move    1,tsfs_extent_media_base
        jumpe   1,test_arm_refuse_v1566
        add     1,010
        move    2,(1)
        came    2,016
        jrst    test_arm_refuse_v1566

        ; TEST ONLY: enable the already source-linked but production-
        ; prohibited physical CLEAN cutover for this one secondary
        ; mount. No scheduler yield between these two stores.
        movei   3,0040000              ; volatile ARMED (physical DIRTY)
        iorm    3,(012)
        movei   3,2                     ; temporary VFS RO bitmap bit
        andcam  3,vfs_mount_policy
        setz    1,
        jrst    test_arm_done_v1566
test_arm_refuse_v1566:
        seto    1,
test_arm_done_v1566:
        pop     17,016
        pop     17,015
        pop     17,014
        pop     17,013
        pop     17,012
        pop     17,011
        pop     17,010
        popj    17,
