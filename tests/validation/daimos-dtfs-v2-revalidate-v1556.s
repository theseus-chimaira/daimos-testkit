; v1556: native PDP-6 mounted READ_SUSPECT recovery oracle.
; The real DTFS V1 parser, V2 validator and mounted recovery execute.
; Only the Type-551 physical RBN0 read is simulated; records originate
; from actual independently formatted host DECtape images.
        .text
        .globl main
        .globl __test_exit
        .globl dtfs_identity_revalidate_v1522
        .globl dtfs_dtc_read_jump
        .globl bcache_workspace_invalidate
        .globl bcache_workspace_tag
        .globl vfs_mount_limit
        .globl vfs_mount_root_base
        .globl vfs_mount_policy
        .globl dtfs_media_base
        .globl tsfs_file_shape_base
        .globl tsfs_extent_media_base
        .globl fs_block_workspace
        .globl kret_zero
        .globl kret_neg1

main:
        movei   010,case_table_v1556
        movei   011,case_count_v1556
case_loop_v1556:
        move    1,(010)                  ; physical source RBN0 record
        movem   1,physical_src_v1556
        move    1,1(010)                 ; original mounted ID source
        move    2,1(1)
        movem   2,shape_v1556
        move    2,2(1)
        movem   2,extent_v1556
        move    1,2(010)
        movem   1,media_v1556
        move    1,3(010)
        movem   1,root_v1556
        move    1,4(010)
        movem   1,vfs_mount_policy
        move    1,5(010)
        movem   1,mode_v1556
        setzm   raw_reads_v1556
        movei   1,04444
        movem   1,bcache_workspace_tag

        ; Deliberately stale complete CLEAN RBN0 in the shared workspace.
        ; No-transfer/short-success raw reads MUST NOT inherit this block.
        movei   2,fs_block_workspace
        hrli    2,record_v2_clean_v1556
        movei   3,fs_block_workspace+0177
        blt     2,(3)

        movei   1,1                     ; public slot ID, not physical unit
        pushj   17,dtfs_identity_revalidate_v1522
        came    1,6(010)
        jrst    case_bad_v1556
        move    1,media_v1556
        came    1,7(010)                ; exact owner/format/suspect bits
        jrst    case_bad_v1556
        move    1,raw_reads_v1556
        came    1,010(010)              ; correct real physical read count
        jrst    case_bad_v1556
        move    1,bcache_workspace_tag
        move    2,011(010)              ; invalidate tag only on raw I/O
        jumpe   2,case_no_invalidate_v1556
        camn    1,[-1]
        jrst    case_done_v1556
        jrst    case_bad_v1556
case_no_invalidate_v1556:
        caie    1,04444
        jrst    case_bad_v1556
case_done_v1556:
        addi    010,012                  ; 10 words per case
        sojg    011,case_loop_v1556
        setz    1,
        popj    17,
case_bad_v1556:
        move    1,011                   ; exact failing case index
        popj    17,

; Raw Type-551 completion fixture: unit=3, reserved block=0, buffer
; must be the common workspace. The production routine itself must
; clear stale scratch before reaching here. Mode 1: physical error;
; 2: incomplete prefix with false successful status; 3: no bytes but
; successful status; 4..9: legitimate I/O plus concurrent changes.
dtfs_dtc_read_jump:
        aos     raw_reads_v1556
        caie    1,3
        jrst    raw_error_v1556
        jumpn   2,raw_error_v1556
        caie    3,fs_block_workspace
        jrst    raw_error_v1556
        move    5,mode_v1556
        caie    5,1
        jrst    raw_not_error_v1556
        jrst    raw_error_v1556
raw_not_error_v1556:
        caie    5,3                     ; false success with zero bytes
        jrst    raw_transfer_v1556
        jrst    raw_after_transfer_v1556
raw_transfer_v1556:
        move    4,physical_src_v1556
        hrl     4,4
        hrri    4,fs_block_workspace
        movei   6,fs_block_workspace+0177
        caie    5,2                     ; incomplete physical prefix
        jrst    raw_full_v1556
        movei   6,fs_block_workspace+2
raw_full_v1556:
        blt     4,(6)
raw_after_transfer_v1556:
        caie    5,4                     ; changing media during sleep
        jrst    raw_no_media_v1556
        movei   4,0400000              ; sticky WRITE_UNCERTAIN
        iorm    4,media_v1556
raw_no_media_v1556:
        caie    5,5                     ; changed high saved ID
        jrst    raw_no_high_v1556
        aos     shape_v1556
raw_no_high_v1556:
        caie    5,6                     ; changed low saved ID
        jrst    raw_no_low_v1556
        aos     extent_v1556
raw_no_low_v1556:
        caie    5,7                     ; loses read-only policy
        jrst    raw_no_rw_v1556
        setzm   vfs_mount_policy
raw_no_rw_v1556:
        caie    5,010                   ; provider changed while sleeping
        jrst    raw_no_provider_v1556
        move    4,[060101000000]
        movem   4,root_v1556
raw_no_provider_v1556:
        caie    5,011                   ; mount ID changed while sleeping
        jrst    raw_success_v1556
        move    4,[050201000000]
        movem   4,root_v1556
raw_success_v1556:
        setz    1,
        popj    17,
raw_error_v1556:
        seto    1,
        popj    17,

kret_zero:
        setz    1,
        popj    17,
kret_neg1:
        seto    1,
        popj    17,

        .data
vfs_mount_limit: .word 1
vfs_mount_root_base: .word root_v1556
vfs_mount_policy: .word 1
dtfs_media_base: .word media_v1556
tsfs_file_shape_base: .word shape_v1556
tsfs_extent_media_base: .word extent_v1556
root_v1556: .word 0
media_v1556: .word 0
shape_v1556: .word 0
extent_v1556: .word 0
physical_src_v1556: .word 0
mode_v1556: .word 0
raw_reads_v1556: .word 0
bcache_workspace_tag: .word 0
        .globl case_table_v1556
        .globl case_count_v1556
        .globl record_v2_clean_v1556
        .bss
fs_block_workspace: .block 0200
__test_exit: .block 1
