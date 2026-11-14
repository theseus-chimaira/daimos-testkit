; v1553 PDP-6: source-linked authenticated per-mount first-write gate.
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
        movei   014,case_table_v1553
        movei   015,022                ; 18 cases, decimal
case_start_v1553:
        move    1,(014)
        movem   1,mode_v1553
        setzm   calls_v1553
        setzm   scratch_base_v1553
        movei   1,1
        movem   1,vfs_mount_limit
        move    1,[050101000000]       ; exact DTFS mount slot zero
        movem   1,mount_root_v1553
        movei   1,0100002             ; DTVOL2, physical DTC unit 2
        movem   1,media_v1553
        movei   1,012345
        movem   1,high_v1553
        movei   1,045670
        movem   1,low_v1553

        move    3,mode_v1553
        caie    3,1                    ; prearmed, no additional physical IO
        jrst    case_not_armed_v1553
        movei   1,0040000
        iorm    1,media_v1553
case_not_armed_v1553:
        caie    3,2                    ; old DTVOL1, no FORMAT_V2 bit
        jrst    case_not_legacy_v1553
        movei   1,2
        movem   1,media_v1553
case_not_legacy_v1553:
        caie    3,3                    ; READ_SUSPECT
        jrst    case_not_read_v1553
        movei   1,0200000
        iorm    1,media_v1553
case_not_read_v1553:
        caie    3,4                    ; WRITE_UNCERTAIN
        jrst    case_not_write_v1553
        movei   1,0400000
        iorm    1,media_v1553
case_not_write_v1553:
        caie    3,5                    ; unrelated D6FS root
        jrst    case_not_provider_v1553
        move    1,[060101000000]
        movem   1,mount_root_v1553
case_not_provider_v1553:
        caie    3,6                    ; wrong public mount ID
        jrst    case_not_mount_id_v1553
        move    1,[050201000000]
        movem   1,mount_root_v1553
case_not_mount_id_v1553:
        caie    3,7                    ; stale media slot, no root
        jrst    case_not_empty_v1553
        setzm   mount_root_v1553
case_not_empty_v1553:
        caie    3,010                  ; zero high identity
        jrst    case_not_high_v1553
        setzm   high_v1553
case_not_high_v1553:
        caie    3,011                  ; zero low identity
        jrst    case_not_low_v1553
        setzm   low_v1553
case_not_low_v1553:
        caie    3,012                  ; previous MM cleanup refusal
        jrst    case_not_owned_v1553
        movei   1,01000
        movem   1,scratch_base_v1553
case_not_owned_v1553:
        caie    3,017                  ; out-of-range VFS slot
        jrst    case_not_limit_v1553
        movei   1,0
        movem   1,vfs_mount_limit
case_not_limit_v1553:
        caie    3,021                  ; mounted UID/GID left-half owner
        jrst    case_not_owner_v1553
        move    1,[012345100002]
        movem   1,media_v1553
case_not_owner_v1553:
        caie    3,020                  ; TENEX or ITS personality
        jrst    case_call_v1553
        movei   1,010
        iorm    1,media_v1553
case_call_v1553:
        setz    1,                     ; mounted zero-based slot
        movei   2,scratch_base_v1553
        move    3,mode_v1553
        caie    3,016                  ; null retained scratch pointer
        jrst    case_call_real_v1553
        setz    2,
case_call_real_v1553:
        pushj   17,dtfs_intent_first_write_v1553
        came    1,1(014)
        jrst    case_bad_v1553
        move    1,calls_v1553
        came    1,2(014)
        jrst    case_bad_v1553
        move    1,media_v1553
        came    1,3(014)
        jrst    case_bad_v1553
        move    1,scratch_base_v1553
        came    1,4(014)
        jrst    case_bad_v1553
        addi    014,5
        sojg    015,case_start_v1553
        setz    1,
        popj    17,
case_bad_v1553:
        move    1,015                  ; failing case index, never zero
        popj    17,

; Strict v1552 physical/MM boundary. Its native behavior has already
; been accepted in v1551-v1552; only the mount authentication is new.
dtfs_intent_owned_arm_v1552:
        aos     calls_v1553
        caie    1,2
        jrst    arm_wrong_v1553
        caie    2,012345
        jrst    arm_wrong_v1553
        caie    3,045670
        jrst    arm_wrong_v1553
        caie    4,scratch_base_v1553
        jrst    arm_wrong_v1553
        skipn   (4)
        jrst    arm_call_valid_v1553
        jrst    arm_wrong_v1553
arm_call_valid_v1553:
        move    5,mode_v1553
        caie    5,013                  ; real physical write/readback fails
        jrst    arm_check_retained_v1553
        seto    1,
        popj    17,
arm_check_retained_v1553:
        caie    5,014                  ; failure also retains MM owner
        jrst    arm_check_change_v1553
        movei   6,02000
        movem   6,scratch_base_v1553
        seto    1,
        popj    17,
arm_check_change_v1553:
        caie    5,015                  ; media altered while I/O slept
        jrst    arm_ok_v1553
        movei   6,0400000
        iorm    6,media_v1553
arm_ok_v1553:
        setz    1,
        popj    17,
arm_wrong_v1553:
        movei   1,0777                ; incorrect ABI must fail native test
        popj    17,

; v1554 source now requires a readback even for the older prearmed case.
; Preserve the v1553 18-case oracle with the v1554 service substituted.
dtfs_intent_owned_verify_v1554:
        aos     calls_v1553
        caie    1,2
        jrst    arm_wrong_v1553
        caie    2,012345
        jrst    arm_wrong_v1553
        caie    3,045670
        jrst    arm_wrong_v1553
        caie    4,scratch_base_v1553
        jrst    arm_wrong_v1553
        setz    1,
        popj    17,

        .data
; Five words per entry: mode, result, physical arm calls, final media,
; retained MM base. All 36-bit values are explicitly octal-prefixed.
case_table_v1553:
        .word 0
        .word 0
        .word 1
        .word 0140002
        .word 0
        .word 1                     ; already armed and unchanged
        .word 0
        .word 1                     ; now physically reverified
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

        .globl vfs_mount_limit
vfs_mount_limit: .word 1
        .globl vfs_mount_root_base
vfs_mount_root_base: .word mount_root_v1553
        .globl dtfs_media_base
dtfs_media_base: .word media_v1553
        .globl tsfs_file_shape_base
tsfs_file_shape_base: .word high_v1553
        .globl tsfs_extent_media_base
tsfs_extent_media_base: .word low_v1553
mount_root_v1553: .word 050101000000
media_v1553: .word 0100002
high_v1553: .word 012345
low_v1553: .word 045670
scratch_base_v1553: .word 0
mode_v1553: .word 0
calls_v1553: .word 0
        .bss
__test_exit: .block 1
