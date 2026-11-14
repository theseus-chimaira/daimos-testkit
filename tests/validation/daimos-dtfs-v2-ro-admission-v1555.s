; Native PDP-6 source-linked v1555 physical DTVOL2/CLEAN RO mount cases.
; The actual dtfs_mount_unit, identity V1 parser and v1550 V2 validator
; are linked from DAIMOS; only raw Type-551 and VFS publication are mocked.
;
; Auxiliary support routines and workspace symbols are extracted from
; the separately accepted v1520 native mount fixture by the test driver.
        .text
        .globl main
        .globl __test_exit
        .globl record_v2_clean_v1555
        .globl record_v2_dirty_v1555
        .globl record_v2_other_v1555
        .globl record_v1_v1555
        .globl record_dir_v1555
        .globl patched_media_v1555
        .globl mount_flags_v1555

main:
        movei   010,case_table_v1555
        movei   011,017                ; 15 independent mount scenarios
case_next_v1555:
        setzm   raw_reads_v1519
        setzm   published_v1519
        setzm   patched_v1519
        setzm   patched_media_v1555
        setzm   dtfs_cache_mount
        movei   4,cache_slab_v1519
        movem   4,bcache_state
        setom   media_online_v1519
        setzm   identity_unreadable_v1520
        movei   4,0111
        movem   4,shape_slabs_v1519+1
        movei   4,0222
        movem   4,extent_slabs_v1519+1

        ; Load *actual* host mkdtfs RBN0144 and RBN0 bytes from the
        ; independently decoded 36-bit low/high image word lanes.
        movei   4,media_dir_v1519
        hrli    4,record_dir_v1555
        movei   5,media_dir_v1519+0177
        blt     4,(5)
        move    6,(010)
        movei   4,media_id_v1519
        hrl     4,6
        movei   5,media_id_v1519+0177
        blt     4,(5)
        move    5,1(010)
        movem   5,mount_flags_v1555

        move    5,6(010)                ; damage-mode enum
        cain    5,1                     ; nonzero padding
        jrst    case_bad_padding_v1555
        cain    5,2                     ; invalid checked seal
        jrst    case_bad_seal_v1555
        cain    5,3                     ; short/failed RBN0 read
        jrst    case_bad_read_v1555
        cain    5,4                     ; bad native directory
        jrst    case_bad_dir_v1555
        cain    5,5                     ; zero high ID with valid checks
        jrst    case_bad_high_v1555
        cain    5,6                     ; zero low ID with valid checks
        jrst    case_bad_low_v1555
        cain    5,7                     ; legacy V1 checksum corrupt
        jrst    case_bad_v1_check_v1555
        jrst    case_mount_v1555
case_bad_padding_v1555:
        movei   5,1
        movem   5,media_id_v1519+040
        jrst    case_mount_v1555
case_bad_seal_v1555:
        movei   5,1
        xorm    5,media_id_v1519+5
        jrst    case_mount_v1555
case_bad_read_v1555:
        setom   identity_unreadable_v1520
        jrst    case_mount_v1555
case_bad_dir_v1555:
        setzm   media_dir_v1519+0177
        jrst    case_mount_v1555
case_bad_high_v1555:
        setzm   media_id_v1519+1
        jrst    case_reseal_v1555
case_bad_low_v1555:
        setzm   media_id_v1519+2
case_reseal_v1555:
        move    5,media_id_v1519
        xor     5,media_id_v1519+1
        xor     5,media_id_v1519+2
        setcm   5,5
        movem   5,media_id_v1519+3
        move    5,media_id_v1519
        xor     5,media_id_v1519+1
        xor     5,media_id_v1519+2
        xor     5,media_id_v1519+4
        xor     5,[0246134572610]
        setcm   5,5
        movem   5,media_id_v1519+5
        jrst    case_mount_v1555
case_bad_v1_check_v1555:
        aos     media_id_v1519+3

case_mount_v1555:
        pushj   17,try_mount_v1519
        came    1,2(010)                ; exact result
        jrst    case_failed_v1555
        move    4,published_v1519
        came    4,3(010)
        jrst    case_failed_v1555
        move    4,patched_v1519
        came    4,3(010)
        jrst    case_failed_v1555
        move    4,patched_media_v1555
        came    4,4(010)                ; exact V2 flag + UNIT + owner
        jrst    case_failed_v1555
        move    4,returned_root_v1519
        skipn   3(010)
        jrst    case_refused_v1555
        came    4,[050201000000]
        jrst    case_failed_v1555
        move    4,shape_slabs_v1519+1
        came    4,media_id_v1519+1
        jrst    case_failed_v1555
        move    4,extent_slabs_v1519+1
        came    4,media_id_v1519+2
        jrst    case_failed_v1555
        jrst    case_final_v1555
case_refused_v1555:
        caie    4,0777
        jrst    case_failed_v1555
        move    4,shape_slabs_v1519+1
        caie    4,0111
        jrst    case_failed_v1555
        move    4,extent_slabs_v1519+1
        caie    4,0222
        jrst    case_failed_v1555
case_final_v1555:
        move    4,raw_reads_v1519
        came    4,5(010)                ; do not bypass physical I/O
        jrst    case_failed_v1555
        addi    010,7
        sojg    011,case_next_v1555
        setz    1,
        popj    17,
case_failed_v1555:
        move    1,011                   ; nonzero failing case index
        popj    17,

        .data
; record ptr, MOUNT flags, expected ret, publications, media,
; physical raw reads, corruption mode.
case_table_v1555:
        .word record_v2_clean_v1555
        .word 011                      ; DTVOL2 CLEAN read-only
        .word 0
        .word 1
        .word 0100003
        .word 2
        .word 0
        .word record_v2_clean_v1555
        .word 010                      ; DTVOL2 CLEAN read-write refused
        .word -1
        .word 0
        .word 0
        .word 2
        .word 0
        .word record_v2_dirty_v1555
        .word 011                      ; DTVOL2 DIRTY even RO refused
        .word -1
        .word 0
        .word 0
        .word 2
        .word 0
        .word record_v2_dirty_v1555
        .word 010                      ; DIRTY writable refused too
        .word -1
        .word 0
        .word 0
        .word 2
        .word 0
        .word record_v2_clean_v1555
        .word 011                      ; corrupted reserved padding
        .word -1
        .word 0
        .word 0
        .word 2
        .word 1
        .word record_v2_clean_v1555
        .word 011                      ; corrupted V2 seal
        .word -1
        .word 0
        .word 0
        .word 2
        .word 2
        .word record_v2_clean_v1555
        .word 011                      ; unreadable identity RBN0
        .word -1
        .word 0
        .word 0
        .word 2
        .word 3
        .word record_v2_clean_v1555
        .word 011                      ; damaged directory admission
        .word -1
        .word 0
        .word 0
        .word 1
        .word 4
        .word record_v2_clean_v1555
        .word 011                      ; zero high ID, rechecked seal
        .word -1
        .word 0
        .word 0
        .word 2
        .word 5
        .word record_v2_clean_v1555
        .word 011                      ; zero low ID, rechecked seal
        .word -1
        .word 0
        .word 0
        .word 2
        .word 6
        .word record_v2_other_v1555
        .word 011                      ; different V2 CLEAN identity RO
        .word 0
        .word 1
        .word 0100003
        .word 2
        .word 0
        .word record_v1_v1555
        .word 010                      ; DTVOL1 RW retains old policy
        .word 0
        .word 1
        .word 3
        .word 2
        .word 0
        .word record_v1_v1555
        .word 011                      ; DTVOL1 RO likewise accepted
        .word 0
        .word 1
        .word 3
        .word 2
        .word 0
        .word record_v1_v1555
        .word 010                      ; malformed V1 identity refused
        .word -1
        .word 0
        .word 0
        .word 2
        .word 7
        .word blank_identity_v1520
        .word 010                      ; legacy all-zero RW preserved
        .word 0
        .word 1
        .word 3
        .word 2
        .word 0

patched_media_v1555: .word 0
mount_flags_v1555: .word 011
