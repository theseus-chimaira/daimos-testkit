; v1554: native PDP-6 physical RBN0 revalidation, controlled DTC boundary.
; The real production DTVOL2 validator and raw-verify instructions execute.
; The physical media words come from genuine opt-in host mkdtfs images.
        .text
        .globl main
        .globl dtfs_intent_verify_v1554
        .globl dtfs_dtc_read_jump
        .globl dtfs_dtc_write_jump
        .globl dtfs_mark_unit_suspect_v1522
        .globl bcache_invalidate_all
        .globl __test_exit

main:
        movei   014,case_table_v1554
        movei   015,021                 ; 17 cases
case_next_v1554:
        move    1,(014)
        movem   1,mode_v1554
        setzm   read_count_v1554
        setzm   write_count_v1554
        setzm   poison_count_v1554
        setzm   flush_count_v1554
        movei   1,012345
        movem   1,pending_data_v1554

        ; Exact host-generated DTVOL2/DIRTY in physically independent
        ; image and scratch arrays. Stale scratch is intentionally DIRTY.
        movei   2,media_v1554
        hrli    2,record_dirty_v1554
        movei   3,media_v1554+0177
        blt     2,(3)
        movei   2,scratch_v1554
        hrli    2,record_dirty_v1554
        movei   3,scratch_v1554+0177
        blt     2,(3)
        move    5,mode_v1554
        caie    5,1                      ; physical DTVOL2/CLEAN
        jrst    case_not_clean_v1554
        movei   2,media_v1554
        hrli    2,record_clean_v1554
        movei   3,media_v1554+0177
        blt     2,(3)
case_not_clean_v1554:
        caie    5,2                      ; old DTVOL1
        jrst    case_not_old_v1554
        movei   2,media_v1554
        hrli    2,record_old_v1554
        movei   3,media_v1554+0177
        blt     2,(3)
case_not_old_v1554:
        caie    5,3                      ; all-zero old legacy
        jrst    case_not_zero_v1554
        movei   2,media_v1554
        movei   3,0200
case_zero_v1554:
        setzm   (2)
        aoj     2,
        sojg    3,case_zero_v1554
case_not_zero_v1554:
        caie    5,4                      ; different *valid* upper ID
        jrst    case_not_other_hi_v1554
        movei   2,media_v1554
        hrli    2,record_other_hi_v1554
        movei   3,media_v1554+0177
        blt     2,(3)
case_not_other_hi_v1554:
        caie    5,5                      ; different *valid* lower ID
        jrst    case_not_other_lo_v1554
        movei   2,media_v1554
        hrli    2,record_other_lo_v1554
        movei   3,media_v1554+0177
        blt     2,(3)
case_not_other_lo_v1554:
        caie    5,6                      ; torn seal
        jrst    case_not_seal_v1554
        movei   2,1
        xorm    2,media_v1554+5
case_not_seal_v1554:
        caie    5,7                      ; bad reserved RBN0 padding
        jrst    case_not_padding_v1554
        movei   2,1
        movem   2,media_v1554+040
case_not_padding_v1554:
        caie    5,017                    ; unknown valid-checksum state
        jrst    case_not_bad_state_v1554
        movei   2,1
        movem   2,media_v1554+4
        move    2,media_v1554
        xor     2,media_v1554+1
        xor     2,media_v1554+2
        xor     2,media_v1554+4
        xor     2,[0246134572610]
        setcm   2,2
        movem   2,media_v1554+5
case_not_bad_state_v1554:
        caie    5,020                    ; bad magic with valid complements
        jrst    case_not_bad_magic_v1554
        move    2,[0446466575423]
        movem   2,media_v1554
        move    2,media_v1554
        xor     2,media_v1554+1
        xor     2,media_v1554+2
        setcm   2,2
        movem   2,media_v1554+3
        move    2,media_v1554
        xor     2,media_v1554+1
        xor     2,media_v1554+2
        xor     2,media_v1554+4
        xor     2,[0246134572610]
        setcm   2,2
        movem   2,media_v1554+5
case_not_bad_magic_v1554:
        movei   1,2                      ; DTC unit
        move    2,record_dirty_v1554+1  ; expected old high ID
        move    3,record_dirty_v1554+2  ; expected old low ID
        movei   4,scratch_v1554
        caie    5,012                    ; invalid expected upper ID
        jrst    case_not_zero_hi_v1554
        setz    2,
case_not_zero_hi_v1554:
        caie    5,013                    ; invalid expected lower ID
        jrst    case_not_zero_lo_v1554
        setz    3,
case_not_zero_lo_v1554:
        caie    5,014                    ; null scratch
        jrst    case_call_v1554
        setz    4,
case_call_v1554:
        pushj   17,dtfs_intent_verify_v1554
        came    1,1(014)                ; exact return
        jrst    case_bad_v1554
        move    1,read_count_v1554
        came    1,2(014)
        jrst    case_bad_v1554
        move    1,poison_count_v1554
        came    1,3(014)
        jrst    case_bad_v1554
        move    1,flush_count_v1554
        came    1,4(014)
        jrst    case_bad_v1554
        skipn   write_count_v1554
        jrst    case_no_write_v1554
        jrst    case_bad_v1554
case_no_write_v1554:
        move    1,pending_data_v1554
        caie    1,012345                ; caller DATA buffer untouched
        jrst    case_bad_v1554
        addi    014,5
        sojg    015,case_next_v1554
        setz    1,
        popj    17,
case_bad_v1554:
        move    1,015                   ; failing case index, nonzero
        popj    17,

; Raw Type-551 I/O controller fixture: unit, reserved RBN0, scratch.
dtfs_dtc_read_jump:
        caie    1,2
        jrst    read_bad_v1554
        jumpn   2,read_bad_v1554
        caie    3,scratch_v1554
        jrst    read_bad_v1554
        aos     read_count_v1554
        move    5,mode_v1554
        caie    5,010                   ; real controller error
        jrst    read_after_error_v1554
        jrst    read_bad_v1554
read_after_error_v1554:
        caie    5,016                   ; false complete: NO transfer
        jrst    read_transfer_v1554
        setz    1,
        popj    17,
read_transfer_v1554:
        movei   5,scratch_v1554
        hrli    5,media_v1554
        movei   6,scratch_v1554+0177
        move    7,mode_v1554
        caie    7,011                   ; false success: partial prefix
        jrst    read_full_v1554
        movei   6,scratch_v1554+3
read_full_v1554:
        blt     5,(6)
        setz    1,
        popj    17,
read_bad_v1554:
        seto    1,
        popj    17,

; Never permit this read-only check to modify physical RBN0.
dtfs_dtc_write_jump:
        aos     write_count_v1554
        seto    1,
        popj    17,

bcache_invalidate_all:
        aos     flush_count_v1554
        popj    17,

dtfs_mark_unit_suspect_v1522:
        caie    1,2
        jrst    poison_wrong_v1554
        caie    2,0400000              ; sticky WRITE_UNCERTAIN
        jrst    poison_wrong_v1554
        aos     poison_count_v1554
        popj    17,
poison_wrong_v1554:
        movei   3,0100
        addm    3,poison_count_v1554
        popj    17,

        .data
; mode / expected result / physical RBN0 reads / poisons / evictions.
case_table_v1554:
        .word 0
        .word 0
        .word 1
        .word 0
        .word 0
        .word 1                       ; clean
        .word -1
        .word 1
        .word 1
        .word 1
        .word 2                       ; old DTVOL1
        .word -1
        .word 1
        .word 1
        .word 1
        .word 3                       ; zero legacy
        .word -1
        .word 1
        .word 1
        .word 1
        .word 4                       ; changed high ID, valid seal
        .word -1
        .word 1
        .word 1
        .word 1
        .word 5                       ; changed low ID, valid seal
        .word -1
        .word 1
        .word 1
        .word 1
        .word 6                       ; torn checksum
        .word -1
        .word 1
        .word 1
        .word 1
        .word 7                       ; corrupted reserved padding
        .word -1
        .word 1
        .word 1
        .word 1
        .word 010                     ; raw DTC read error
        .word -1
        .word 1
        .word 1
        .word 1
        .word 011                     ; incomplete raw DTC prefix
        .word -1
        .word 1
        .word 1
        .word 1
        .word 012                     ; bad expected high ID, no I/O
        .word -1
        .word 0
        .word 0
        .word 0
        .word 013                     ; bad expected low ID, no I/O
        .word -1
        .word 0
        .word 0
        .word 0
        .word 014                     ; null scratch, no I/O
        .word -1
        .word 0
        .word 0
        .word 0
        .word 015                     ; repeated correct DIRTY record
        .word 0
        .word 1
        .word 0
        .word 0
        .word 016                     ; read returns success, no bytes
        .word -1
        .word 1
        .word 1
        .word 1
        .word 017                     ; invalid state, valid checksum
        .word -1
        .word 1
        .word 1
        .word 1
        .word 020                     ; wrong magic, valid checksum
        .word -1
        .word 1
        .word 1
        .word 1

        .globl record_dirty_v1554
        .globl record_clean_v1554
        .globl record_old_v1554
        .globl record_other_hi_v1554
        .globl record_other_lo_v1554
        .bss
media_v1554: .block 0200
scratch_v1554: .block 0200
mode_v1554: .block 1
read_count_v1554: .block 1
write_count_v1554: .block 1
poison_count_v1554: .block 1
flush_count_v1554: .block 1
pending_data_v1554: .block 0200
__test_exit: .block 1
