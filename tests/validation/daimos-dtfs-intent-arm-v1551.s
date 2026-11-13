; Test-only physical DTC boundaries for the real v1551 arm service.
; The record validator and arm service are linked from actual DAIMOS source.
        .text
        .globl main
        .globl dtfs_intent_arm_v1551
        .globl dtfs_dtc_read_jump
        .globl dtfs_dtc_write_jump
        .globl dtfs_mark_unit_suspect_v1522
        .globl bcache_invalidate_all
        .globl __test_exit

main:
        movei   014,case_table_v1551
        movei   015,016                 ; 14 distinct ordered scenarios
case_next_v1551:
        move    1,(014)
        movem   1,test_mode_v1551
        setzm   read_count_v1551
        setzm   write_count_v1551
        setzm   poison_count_v1551
        setzm   invalidates_v1551
        movei   1,fs_data_v1551
        movei   2,012345
        movem   2,(1)                   ; original caller data sentinel

        ; Both inputs are real host-generated 36-bit image records.
        move    1,test_mode_v1551
        caie    1,1                     ; already-DIRTY medium
        jrst    case_not_dirty_v1551
        movei   2,media_v1551
        hrli    2,record_dirty_v1551
        jrst    case_copy_v1551
case_not_dirty_v1551:
        caie    1,2                     ; DTVOL1 medium
        jrst    case_normal_media_v1551
        movei   2,media_v1551
        hrli    2,record_legacy_v1551
        jrst    case_copy_v1551
case_normal_media_v1551:
        movei   2,media_v1551
        hrli    2,record_clean_v1551
case_copy_v1551:
        movei   3,media_v1551+0177
        blt     2,(3)

        movei   1,2                     ; physical Type-551 unit
        move    2,record_clean_v1551+1 ; previously mounted 72-bit ID
        move    3,record_clean_v1551+2
        movei   4,scratch_v1551
        move    5,test_mode_v1551
        caie    5,3                     ; wrong expected ID
        jrst    case_check_low_v1551
        aoj     2,
case_check_low_v1551:
        caie    5,015                   ; wrong expected LOW ID
        jrst    case_check_zero_low_v1551
        aoj     3,
case_check_zero_low_v1551:
        caie    5,012                   ; zero low ID, refused pre-I/O
        jrst    case_check_buffer_v1551
        setz    3,
case_check_buffer_v1551:
        caie    5,013                   ; no caller scratch
        jrst    case_call_v1551
        setz    4,
case_call_v1551:
        pushj   17,dtfs_intent_arm_v1551
        came    1,1(014)                ; exact error/status expectation
        jrst    case_failed_v1551
        move    1,read_count_v1551
        came    1,2(014)
        jrst    case_failed_v1551
        move    1,write_count_v1551
        came    1,3(014)
        jrst    case_failed_v1551
        move    1,poison_count_v1551
        came    1,4(014)
        jrst    case_failed_v1551
        move    1,invalidates_v1551
        came    1,5(014)
        jrst    case_failed_v1551
        move    1,fs_data_v1551
        caie    1,012345                ; pending filesystem buffer intact
        jrst    case_failed_v1551
        addi    014,6
        sojg    015,case_next_v1551
        setz    1,
        popj    17,
case_failed_v1551:
        move    1,015                   ; failing case index, nonzero
        popj    17,

; Raw physical read ABI. All readback cases observe MEDIA, not SCRATCH.
dtfs_dtc_read_jump:
        caie    1,2
        jrst    raw_error_v1551
        jumpn   2,raw_error_v1551
        aos     read_count_v1551
        move    5,test_mode_v1551
        caie    5,4                     ; first read fails
        jrst    raw_read_second_v1551
        jrst    raw_error_v1551
raw_read_second_v1551:
        caie    5,6                     ; post-WRITE read fails
        jrst    raw_read_copy_v1551
        move    6,read_count_v1551
        caie    6,2
        jrst    raw_read_copy_v1551
        jrst    raw_error_v1551
raw_read_copy_v1551:
        move    5,3
        hrli    5,media_v1551
        movei   6,0177(3)
        blt     5,(6)
        setz    1,
        popj    17,

; Raw write ABI. Mode 5 is an interrupted one-word marker write;
; mode 7 acknowledges a write without changing the physical image;
; mode 8 changes only state word; mode 9 corrupts identity after write.
dtfs_dtc_write_jump:
        caie    1,2
        jrst    raw_error_v1551
        jumpn   2,raw_error_v1551
        aos     write_count_v1551
        move    5,test_mode_v1551
        caie    5,7
        jrst    raw_write_maybe_partial_v1551
        setz    1,
        popj    17,
raw_write_maybe_partial_v1551:
        caie    5,5
        jrst    raw_write_maybe_torn_v1551
        move    6,4(3)
        movem   6,media_v1551+4
        jrst    raw_error_v1551
raw_write_maybe_torn_v1551:
        caie    5,010                  ; 010 is decimal 8 in assembler
        jrst    raw_write_full_v1551
        move    6,4(3)
        movem   6,media_v1551+4
        setz    1,
        popj    17,
raw_write_full_v1551:
        movei   5,media_v1551
        hrl     5,3                     ; actual caller scratch pointer
        movei   6,media_v1551+0177
        blt     5,(6)
        move    5,test_mode_v1551
        caie    5,011                  ; octal 11 = decimal 9
        jrst    raw_write_ok_v1551
        aos     media_v1551+1          ; physically changed high ID
raw_write_ok_v1551:
        setz    1,
        popj    17,
raw_error_v1551:
        seto    1,
        popj    17,

dtfs_mark_unit_suspect_v1522:
        caie    1,2
        jrst    poison_wrong_v1551
        caie    2,0400000              ; exactly WRITE_UNCERTAIN
        jrst    poison_wrong_v1551
        aos     poison_count_v1551
        popj    17,
poison_wrong_v1551:
        movei   5,0100
        addm    5,poison_count_v1551
        popj    17,

bcache_invalidate_all:
        aos     invalidates_v1551
        popj    17,

        .data
; scenario numbers are DECIMAL in this table, via the leading zero
; convention for octal if used in assembler immediates.
case_table_v1551:
        ; One word per directive: das does not accept comma-separated
        ; multiword initializers. Each entry is six consecutive words:
        ; mode / result / reads / writes / poisoned mounts / evictions.
        .word 0                       ; clean->dirty readback
        .word 0
        .word 2
        .word 1
        .word 0
        .word 1
        .word 1                       ; preexisting dirty
        .word -1
        .word 1
        .word 0
        .word 0
        .word 0
        .word 2                       ; DTVOL1
        .word -1
        .word 1
        .word 0
        .word 0
        .word 0
        .word 3                       ; wrong expected high ID
        .word -1
        .word 1
        .word 0
        .word 0
        .word 0
        .word 4                       ; initial read failure
        .word -1
        .word 1
        .word 0
        .word 0
        .word 0
        .word 5                       ; physical partial write failure
        .word -1
        .word 1
        .word 1
        .word 1
        .word 1
        .word 6                       ; readback error
        .word -1
        .word 2
        .word 1
        .word 1
        .word 1
        .word 7                       ; false hardware write success
        .word -1
        .word 2
        .word 1
        .word 1
        .word 1
        .word 010                     ; torn marker returned success
        .word -1
        .word 2
        .word 1
        .word 1
        .word 1
        .word 011                     ; ID physically changed
        .word -1
        .word 2
        .word 1
        .word 1
        .word 1
        .word 012                     ; zero expected low ID
        .word -1
        .word 0
        .word 0
        .word 0
        .word 0
        .word 013                     ; no scratch buffer
        .word -1
        .word 0
        .word 0
        .word 0
        .word 0
        .word 014                     ; repeat complete success
        .word 0
        .word 2
        .word 1
        .word 0
        .word 1
        .word 015                     ; wrong expected low ID
        .word -1
        .word 1
        .word 0
        .word 0
        .word 0
        .globl record_clean_v1551
        .globl record_dirty_v1551
        .globl record_legacy_v1551
        .bss
test_mode_v1551: .block 1
read_count_v1551: .block 1
write_count_v1551: .block 1
poison_count_v1551: .block 1
invalidates_v1551: .block 1
media_v1551: .block 0200
scratch_v1551: .block 0200
fs_data_v1551: .block 0200
__test_exit: .block 1
