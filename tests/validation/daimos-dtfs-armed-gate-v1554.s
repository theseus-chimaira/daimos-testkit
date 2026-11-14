; v1554 PDP-6: source-linked authenticated per-mount first-write gate.
; The v1552 MM+physical boundary is deliberately a strict status oracle.
        .text
        .globl main
        .globl __test_exit
        .globl dtfs_intent_first_write_v1553
        .globl dtfs_intent_owned_arm_v1552
        .globl dtfs_intent_owned_verify_v1554
        .globl vfs_mount_root_base
        .globl vfs_mount_limit
        .globl dtfs_media_base
        .globl tsfs_file_shape_base
        .globl tsfs_extent_media_base

main:
        movei   014,case_table_v1554
        movei   015,027                ; 23 cases (octal 027)
case_start_v1554:
        move    1,(014)
        movem   1,mode_v1554
        setzm   calls_v1554
        setzm   scratch_base_v1554
        movei   1,1
        movem   1,vfs_mount_limit
        move    1,[050101000000]       ; exact DTFS mount slot zero
        movem   1,mount_root_v1554
        movei   1,0100002             ; DTVOL2, physical DTC unit 2
        movem   1,media_v1554
        movei   1,012345
        movem   1,high_v1554
        movei   1,045670
        movem   1,low_v1554

        move    3,mode_v1554
        caie    3,1                    ; prearmed, no additional physical IO
        jrst    case_maybe_prearmed_v1554
        jrst    case_set_prearmed_v1554
case_maybe_prearmed_v1554:
        caige   3,022                  ; new readback failure/mutation cases
        jrst    case_not_armed_v1554
        caige   3,027
        jrst    case_set_prearmed_v1554
        jrst    case_not_armed_v1554
case_set_prearmed_v1554:
        movei   1,0040000
        iorm    1,media_v1554
case_not_armed_v1554:
        caie    3,2                    ; old DTVOL1, no FORMAT_V2 bit
        jrst    case_not_legacy_v1554
        movei   1,2
        movem   1,media_v1554
case_not_legacy_v1554:
        caie    3,3                    ; READ_SUSPECT
        jrst    case_not_read_v1554
        movei   1,0200000
        iorm    1,media_v1554
case_not_read_v1554:
        caie    3,4                    ; WRITE_UNCERTAIN
        jrst    case_not_write_v1554
        movei   1,0400000
        iorm    1,media_v1554
case_not_write_v1554:
        caie    3,5                    ; unrelated D6FS root
        jrst    case_not_provider_v1554
        move    1,[060101000000]
        movem   1,mount_root_v1554
case_not_provider_v1554:
        caie    3,6                    ; wrong public mount ID
        jrst    case_not_mount_id_v1554
        move    1,[050201000000]
        movem   1,mount_root_v1554
case_not_mount_id_v1554:
        caie    3,7                    ; stale media slot, no root
        jrst    case_not_empty_v1554
        setzm   mount_root_v1554
case_not_empty_v1554:
        caie    3,010                  ; zero high identity
        jrst    case_not_high_v1554
        setzm   high_v1554
case_not_high_v1554:
        caie    3,011                  ; zero low identity
        jrst    case_not_low_v1554
        setzm   low_v1554
case_not_low_v1554:
        caie    3,012                  ; previous MM cleanup refusal
        jrst    case_not_owned_v1554
        movei   1,01000
        movem   1,scratch_base_v1554
case_not_owned_v1554:
        caie    3,017                  ; out-of-range VFS slot
        jrst    case_not_limit_v1554
        movei   1,0
        movem   1,vfs_mount_limit
case_not_limit_v1554:
        caie    3,021                  ; mounted UID/GID left-half owner
        jrst    case_not_owner_v1554
        move    1,[012345100002]
        movem   1,media_v1554
case_not_owner_v1554:
        caie    3,020                  ; TENEX or ITS personality
        jrst    case_call_v1554
        movei   1,010
        iorm    1,media_v1554
case_call_v1554:
        setz    1,                     ; mounted zero-based slot
        movei   2,scratch_base_v1554
        move    3,mode_v1554
        caie    3,016                  ; null retained scratch pointer
        jrst    case_call_real_v1554
        setz    2,
case_call_real_v1554:
        pushj   17,dtfs_intent_first_write_v1553
        came    1,1(014)
        jrst    case_bad_v1554
        move    1,calls_v1554
        came    1,2(014)
        jrst    case_bad_v1554
        move    1,media_v1554
        came    1,3(014)
        jrst    case_bad_v1554
        move    1,scratch_base_v1554
        came    1,4(014)
        jrst    case_bad_v1554
        addi    014,5
        sojg    015,case_start_v1554
        setz    1,
        popj    17,
case_bad_v1554:
        move    1,015                  ; failing case index, never zero
        popj    17,

; Strict v1552 physical/MM boundary. Its native behavior has already
; been accepted in v1551-v1552; only the mount authentication is new.
dtfs_intent_owned_arm_v1552:
        aos     calls_v1554
        caie    1,2
        jrst    arm_wrong_v1554
        caie    2,012345
        jrst    arm_wrong_v1554
        caie    3,045670
        jrst    arm_wrong_v1554
        caie    4,scratch_base_v1554
        jrst    arm_wrong_v1554
        skipn   (4)
        jrst    arm_call_valid_v1554
        jrst    arm_wrong_v1554
arm_call_valid_v1554:
        move    5,mode_v1554
        caie    5,013                  ; real physical write/readback fails
        jrst    arm_check_retained_v1554
        seto    1,
        popj    17,
arm_check_retained_v1554:
        caie    5,014                  ; failure also retains MM owner
        jrst    arm_check_change_v1554
        movei   6,02000
        movem   6,scratch_base_v1554
        seto    1,
        popj    17,
arm_check_change_v1554:
        caie    5,015                  ; media altered while I/O slept
        jrst    arm_ok_v1554
        movei   6,0400000
        iorm    6,media_v1554
arm_ok_v1554:
        setz    1,
        popj    17,
arm_wrong_v1554:
        movei   1,0777                ; incorrect ABI must fail native test
        popj    17,

; Each subsequent write must call the pinned physical DIRTY verifier.
dtfs_intent_owned_verify_v1554:
        aos     calls_v1554
        caie    1,2
        jrst    arm_wrong_v1554
        caie    2,012345
        jrst    arm_wrong_v1554
        caie    3,045670
        jrst    arm_wrong_v1554
        caie    4,scratch_base_v1554
        jrst    arm_wrong_v1554
        move    5,mode_v1554
        caie    5,022                  ; physical DIRTY readback refused
        jrst    verify_no_failure_v1554
        seto    1,
        popj    17,
verify_no_failure_v1554:
        caie    5,023                  ; new WRITE_UNCERTAIN during I/O
        jrst    verify_no_poison_v1554
        movei   6,0400000
        iorm    6,media_v1554
verify_no_poison_v1554:
        caie    5,024                  ; saved high ID changed during read
        jrst    verify_no_high_change_v1554
        aos     high_v1554
verify_no_high_change_v1554:
        caie    5,025                  ; saved low ID changed during read
        jrst    verify_no_low_change_v1554
        aos     low_v1554
verify_no_low_change_v1554:
        caie    5,026                  ; MM cleanup retained an extent
        jrst    verify_no_owned_v1554
        movei   6,01000
        movem   6,scratch_base_v1554
verify_no_owned_v1554:
        setz    1,
        popj    17,

        .data
; Five words per entry: mode, result, physical arm calls, final media,
; retained MM base. All 36-bit values are explicitly octal-prefixed.
case_table_v1554:
        .word 0
        .word 0
        .word 1
        .word 0140002
        .word 0
        .word 1                     ; already armed and unchanged
        .word 0
        .word 1                     ; verified with new raw readback
        .word 0140002
        .word 0
        .word 2                     ; legacy
        .word -1
        .word 0
        .word 2
        .word 0
        .word 3                     ; read suspect
        .word -1
        .word 0
        .word 0300002
        .word 0
        .word 4                     ; write uncertain
        .word -1
        .word 0
        .word 0500002
        .word 0
        .word 5                     ; wrong provider
        .word -1
        .word 0
        .word 0100002
        .word 0
        .word 6                     ; wrong mount token
        .word -1
        .word 0
        .word 0100002
        .word 0
        .word 7                     ; retired mount root
        .word -1
        .word 0
        .word 0100002
        .word 0
        .word 010                   ; high half absent
        .word -1
        .word 0
        .word 0100002
        .word 0
        .word 011                   ; low half absent
        .word -1
        .word 0
        .word 0100002
        .word 0
        .word 012                   ; preexisting MM scratch owner
        .word -1
        .word 0
        .word 0100002
        .word 01000
        .word 013                   ; hardware arm refusal
        .word -1
        .word 1
        .word 0100002
        .word 0
        .word 014                   ; refused MM cleanup, preserve owner
        .word -1
        .word 1
        .word 0100002
        .word 02000
        .word 015                   ; media word changed during arm
        .word -1
        .word 1
        .word 0500002
        .word 0
        .word 016                   ; null scratch basep
        .word -1
        .word 0
        .word 0100002
        .word 0
        .word 017                   ; VFS mount index beyond limit
        .word -1
        .word 0
        .word 0100002
        .word 0
        .word 020                   ; foreign personality
        .word -1
        .word 0
        .word 0100012
        .word 0
        .word 021                   ; retain owner18 in media LH
        .word 0
        .word 1
        .word 012345140002
        .word 0
        .word 022                   ; physical verification refused
        .word -1
        .word 1
        .word 0140002
        .word 0
        .word 023                   ; physical I/O marks mounted suspect
        .word -1
        .word 1
        .word 0540002
        .word 0
        .word 024                   ; high saved ID changed during read
        .word -1
        .word 1
        .word 0140002
        .word 0
        .word 025                   ; low saved ID changed during read
        .word -1
        .word 1
        .word 0140002
        .word 0
        .word 026                   ; retained MM base after readback
        .word -1
        .word 1
        .word 0140002
        .word 01000

        .globl vfs_mount_limit
vfs_mount_limit: .word 1
        .globl vfs_mount_root_base
vfs_mount_root_base: .word mount_root_v1554
        .globl dtfs_media_base
dtfs_media_base: .word media_v1554
        .globl tsfs_file_shape_base
tsfs_file_shape_base: .word high_v1554
        .globl tsfs_extent_media_base
tsfs_extent_media_base: .word low_v1554
mount_root_v1554: .word 050101000000
media_v1554: .word 0100002
high_v1554: .word 012345
low_v1554: .word 045670
scratch_base_v1554: .word 0
mode_v1554: .word 0
calls_v1554: .word 0
        .bss
__test_exit: .block 1
