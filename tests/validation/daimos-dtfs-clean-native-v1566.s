; Native real PDP-6 source-linked RBN0 DIRTY -> CLEAN raw transaction.
; Only physical Type-551 transfer, BCACHE and suspect callbacks are
; replaced with strict stateful test oracles. The production validator
; and production dtfs_intent_clean_v1566 instructions are linked unchanged.
        .text
        .globl main
        .globl dtfs_intent_clean_v1566
        .globl dtfs_dtc_read_jump
        .globl dtfs_dtc_write_jump
        .globl dtfs_mark_unit_suspect_v1522
        .globl bcache_invalidate_all
        .globl __test_exit

main:
        movei   014,cases_v1566
        movei   015,case_count_v1566
case_next_v1566:
        move    1,(014)
        movem   1,mode_v1566
        setzm   read_count_v1566
        setzm   write_count_v1566
        setzm   poison_count_v1566
        setzm   evict_count_v1566
        movei   2,media_v1566
        hrli    2,record_dirty_v1566
        movei   3,media_v1566+0177
        blt     2,(3)
        move    5,mode_v1566
        caie    5,1                     ; already CLEAN initially
        jrst    case_initial_dirty_v1566
        movei   2,media_v1566
        hrli    2,record_clean_v1566
        movei   3,media_v1566+0177
        blt     2,(3)
case_initial_dirty_v1566:
        caie    5,2                     ; valid other 72-bit ID, not ours
        jrst    case_bad_seal_v1566
        movei   2,media_v1566
        hrli    2,record_other_v1566
        movei   3,media_v1566+0177
        blt     2,(3)
case_bad_seal_v1566:
        caie    5,3                     ; invalid salted seal
        jrst    case_padding_v1566
        aos     media_v1566+5
case_padding_v1566:
        caie    5,4
        jrst    case_scratch_v1566
        movei   1,1
        movem   1,media_v1566+6
case_scratch_v1566:
        ; Reuse a complete old DIRTY scratch to expose short transfers.
        movei   2,scratch_v1566
        hrli    2,record_dirty_v1566
        movei   3,scratch_v1566+0177
        blt     2,(3)
        movei   1,012345
        movem   1,pending_data_v1566
        movei   1,2                     ; physical DTC unit
        move    2,record_dirty_v1566+1
        move    3,record_dirty_v1566+2
        movei   4,scratch_v1566
        move    5,mode_v1566
        caie    5,013                   ; wrong expected HIGH ID
        jrst    case_low_v1566
        aoj     2,
case_low_v1566:
        caie    5,014                   ; wrong expected LOW ID
        jrst    case_zero_high_v1566
        aoj     3,
case_zero_high_v1566:
        caie    5,016                   ; zero HIGH ID
        jrst    case_zero_low_v1566
        setz    2,
case_zero_low_v1566:
        caie    5,017                   ; zero LOW ID
        jrst    case_missing_buffer_v1566
        setz    3,
case_missing_buffer_v1566:
        caie    5,015                   ; no scratch pointer
        jrst    case_run_v1566
        setz    4,
case_run_v1566:
        pushj   17,dtfs_intent_clean_v1566
        came    1,1(014)
        jrst    case_bad_v1566
        move    1,read_count_v1566
        came    1,2(014)
        jrst    case_bad_v1566
        move    1,write_count_v1566
        came    1,3(014)
        jrst    case_bad_v1566
        move    1,poison_count_v1566
        came    1,4(014)
        jrst    case_bad_v1566
        move    1,evict_count_v1566
        came    1,5(014)
        jrst    case_bad_v1566
        move    1,media_v1566+4
        came    1,6(014)                ; exact on-media state word
        jrst    case_bad_v1566
        move    1,pending_data_v1566
        caie    1,012345               ; data write buffer untouched
        jrst    case_bad_v1566
        addi    014,7                   ; seven case table words
        sojg    015,case_next_v1566
        setz    1,
        popj    17,
case_bad_v1566:
        move    1,015                   ; always nonzero case number
        popj    17,

; Reads are always real physical MEDIA copies, never a cache hit.
dtfs_dtc_read_jump:
        caie    1,2
        jrst    bad_physical_v1566
        jumpn   2,bad_physical_v1566
        aos     read_count_v1566
        move    5,mode_v1566
        caie    5,6                     ; first read I/O failure
        jrst    raw_read_second_v1566
        jrst    bad_physical_v1566
raw_read_second_v1566:
        caie    5,011                   ; readback I/O error
        jrst    raw_read_zero_first_v1566
        move    6,read_count_v1566
        caie    6,2
        jrst    raw_read_zero_first_v1566
        jrst    bad_physical_v1566
raw_read_zero_first_v1566:
        caie    5,5                     ; zero-byte successful first read
        jrst    raw_read_zero_second_v1566
        move    6,read_count_v1566
        caie    6,1
        jrst    raw_read_zero_second_v1566
        setz    1,
        popj    17,
raw_read_zero_second_v1566:
        caie    5,012                   ; zero-byte successful readback
        jrst    raw_read_copy_v1566
        move    6,read_count_v1566
        caie    6,2
        jrst    raw_read_copy_v1566
        setz    1,
        popj    17,
raw_read_copy_v1566:
        move    5,3
        hrli    5,media_v1566
        movei   6,0177(3)
        blt     5,(6)
        setz    1,
        popj    17,

dtfs_dtc_write_jump:
        caie    1,2
        jrst    bad_physical_v1566
        jumpn   2,bad_physical_v1566
        aos     write_count_v1566
        move    5,mode_v1566
        caie    5,010                   ; ACK without altering physical RBN0
        jrst    raw_write_partial_v1566
        setz    1,
        popj    17,
raw_write_partial_v1566:
        caie    5,7                     ; partially wrote CLEAN word4
        jrst    raw_write_full_v1566
        move    6,4(3)
        movem   6,media_v1566+4
        jrst    bad_physical_v1566
raw_write_full_v1566:
        movei   5,media_v1566
        hrl     5,3
        movei   6,media_v1566+0177
        blt     5,(6)
        move    5,mode_v1566
        caie    5,020                   ; physically changed HIGH ID
        jrst    raw_write_low_v1566
        aos     media_v1566+1
raw_write_low_v1566:
        caie    5,021                   ; physically changed LOW ID
        jrst    raw_write_return_v1566
        aos     media_v1566+2
raw_write_return_v1566:
        setz    1,
        popj    17,
bad_physical_v1566:
        seto    1,
        popj    17,

dtfs_mark_unit_suspect_v1522:
        caie    1,2
        jrst    bad_poison_v1566
        caie    2,0400000
        jrst    bad_poison_v1566
        aos     poison_count_v1566
        popj    17,
bad_poison_v1566:
        movei   5,0100
        addm    5,poison_count_v1566
        popj    17,
bcache_invalidate_all:
        aos     evict_count_v1566
        popj    17,

        .data
        .globl cases_v1566
        .globl case_count_v1566
        .globl record_dirty_v1566
        .globl record_clean_v1566
        .globl record_other_v1566
mode_v1566: .word 0
read_count_v1566: .word 0
write_count_v1566: .word 0
poison_count_v1566: .word 0
evict_count_v1566: .word 0
pending_data_v1566: .word 0
media_v1566: .block 0200
scratch_v1566: .block 0200
        .bss
__test_exit: .block 1
