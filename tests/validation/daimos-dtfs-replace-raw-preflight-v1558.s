; v1558: run genuine production PDP-6 DTFS replacement admission with
; raw Type-551 transfer oracles and independently formatted media images.
        .text
        .globl main
        .globl __test_exit
        .globl dtfs_verify_replacement_v1531
        .globl dtfs_dtc_read_jump
        .globl bcache_invalidate_all
        .globl dtfs_media_base
        .globl tsfs_file_shape_base
        .globl tsfs_extent_media_base
        .globl dtfs_cache_mount
        .globl fs_block_workspace

main:
        movei   010,cases_v1558
        movei   012,case_count_v1558
case_next_v1558:
        move    4,(010)
        movem   4,physical_identity_v1558
        move    4,1(010)
        movem   4,mode_v1558
        move    4,2(010)
        movem   4,mounted_media_v1558
        move    4,3(010)
        move    5,1(4)                  ; original saved 72-bit ID
        movem   5,shape_v1558
        move    5,2(4)
        movem   5,extent_v1558
        move    4,mode_v1558
        caie    4,020                   ; old high half missing
        jrst    case_old_low_v1558
        setzm   shape_v1558
case_old_low_v1558:
        caie    4,021                   ; old low half missing
        jrst    case_ready_v1558
        setzm   extent_v1558
case_ready_v1558:
        setzm   raw_reads_v1558
        setzm   invalidates_v1558
        movei   5,0222
        movem   5,dtfs_cache_mount
        ; A previously used workspace can contain a complete valid
        ; native directory when an earlier Type-551 transfer was done.
        movei   4,fs_block_workspace
        hrli    4,record_dir_v1558
        movei   5,fs_block_workspace+0177
        blt     4,(5)

        setz    1,                       ; zero-based poisoned VFS slot
        pushj   17,dtfs_verify_replacement_v1531
        came    1,4(010)
        jrst    case_failed_v1558
        move    4,raw_reads_v1558
        came    4,5(010)
        jrst    case_failed_v1558
        move    4,invalidates_v1558
        came    4,6(010)
        jrst    case_failed_v1558
        move    4,dtfs_cache_mount
        move    5,6(010)
        jumpe   5,case_no_cache_v1558
        jumpe   4,case_done_v1558
        jrst    case_failed_v1558
case_no_cache_v1558:
        caie    4,0222
        jrst    case_failed_v1558
case_done_v1558:
        addi    010,7
        sojg    012,case_next_v1558
        setz    1,
        popj    17,
case_failed_v1558:
        move    1,012                    ; nonzero failing case index
        popj    17,

dtfs_dtc_read_jump:
        caie    1,3                      ; exact physical unit and buffer
        jrst    physical_error_v1558
        caie    3,fs_block_workspace
        jrst    physical_error_v1558
        aos     raw_reads_v1558
        move    7,mode_v1558
        caie    2,0144                  ; directory RBN0144
        jrst    raw_identity_v1558
        caie    7,1                     ; directory false-success, zero
        jrst    raw_directory_short_v1558
        setz    1,
        popj    17,
raw_directory_short_v1558:
        caie    7,2                     ; directory false-success prefix
        jrst    raw_directory_error_v1558
        move    4,3
        hrli    4,record_dir_v1558
        movei   5,2(3)
        blt     4,(5)
        setz    1,
        popj    17,
raw_directory_error_v1558:
        caie    7,3
        jrst    raw_directory_full_v1558
        jrst    physical_error_v1558
raw_directory_full_v1558:
        move    4,3
        hrli    4,record_dir_v1558
        movei   5,0177(3)
        blt     4,(5)
        caie    7,4                     ; wrong directory magic
        jrst    dir_owner0_v1558
        setzm   fs_block_workspace+0177
dir_owner0_v1558:
        caie    7,5                     ; block-zero owner missing
        jrst    dir_owner144_v1558
        setzm   fs_block_workspace
dir_owner144_v1558:
        caie    7,6                     ; own directory block unreserved
        jrst    dir_tags_v1558
        setzm   fs_block_workspace+016
dir_tags_v1558:
        caie    7,7                     ; bad final native tags
        jrst    physical_success_v1558
        setzm   fs_block_workspace+0122
        jrst    physical_success_v1558

raw_identity_v1558:
        jumpn   2,physical_error_v1558 ; reserved RBN0 only
        caie    7,010                   ; zero-byte read false success
        jrst    raw_id_short_v1558
        setz    1,
        popj    17,
raw_id_short_v1558:
        caie    7,011                   ; short 3-word prefix
        jrst    raw_id_error_v1558
        move    4,3
        hrl     4,physical_identity_v1558
        movei   5,2(3)
        blt     4,(5)
        setz    1,
        popj    17,
raw_id_error_v1558:
        caie    7,012
        jrst    raw_id_full_v1558
        jrst    physical_error_v1558
raw_id_full_v1558:
        move    4,3
        hrl     4,physical_identity_v1558
        movei   5,0177(3)
        blt     4,(5)
        caie    7,013                   ; broken identity checksum
        jrst    raw_id_padding_v1558
        aos     fs_block_workspace+3
raw_id_padding_v1558:
        caie    7,014                   ; nonzero reserved padding
        jrst    physical_success_v1558
        aos     fs_block_workspace+040
physical_success_v1558:
        setz    1,
        popj    17,
physical_error_v1558:
        seto    1,
        popj    17,

bcache_invalidate_all:
        aos     invalidates_v1558
        popj    17,

        .data
dtfs_media_base: .word mounted_media_v1558
tsfs_file_shape_base: .word shape_v1558
tsfs_extent_media_base: .word extent_v1558
dtfs_cache_mount: .word 0
mounted_media_v1558: .word 0
shape_v1558: .word 0
extent_v1558: .word 0
physical_identity_v1558: .word 0
mode_v1558: .word 0
raw_reads_v1558: .word 0
invalidates_v1558: .word 0
        .globl record_dir_v1558
        .globl cases_v1558
        .globl case_count_v1558
        .bss
fs_block_workspace: .block 0200
__test_exit: .block 1
