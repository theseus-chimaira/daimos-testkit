; Real TSFS metadata/table and stored/BLOCK file I/O under v1538.
; The source-linked metadata and file-data readers make the root decision.
; Only the physical DTC callback and unrelated VM helpers are test doubles.
        .text
        .globl main
        .globl __test_exit
        .globl tsfs_file_record
        .globl tsfs_read_words
        .globl dtfs_dtc_read
        .globl tsfs_node_record
        .globl fs_copy_words
        .globl fs_block_workspace
        .globl vfs_namespace_root
        .globl dtfs_media_base
        .globl tsfs_extent_media_base
        .globl tsfs_file_shape_base
        .globl kconst_7_7
        .globl kconst_1_1
        .globl mm_alloc
        .globl mm_free
        .globl d6codec_decode_buffer_v1458
        .globl kret_zero
        .globl kret_neg1

main:
        setzm   io_count_v1538
        skipn   test_mode_v1538
        jrst    test_metadata_v1538
        move    1,test_vnode_v1538
        setz    2,                      ; offset zero
        movei   3,result_v1538
        move    4,test_count_v1538
        pushj   17,tsfs_read_words
        jrst    test_result_v1538
test_metadata_v1538:
        move    1,test_vnode_v1538
        move    2,test_index_v1538
        pushj   17,tsfs_file_record
test_result_v1538:
        camn    1,test_expected_v1538
        jrst    test_io_count_v1538
        movei   1,7
        popj    17,
test_io_count_v1538:
        move    2,io_count_v1538
        camn    2,test_expected_io_v1538
        jrst    test_pass_v1538
        movei   1,6
        popj    17,
test_pass_v1538:
        setz    1,
        popj    17,

; Return a legitimate file-record pointer. TSFS extent and physical data
; access remain the actual production implementation.
tsfs_node_record:
        movei   1,tsfs_file_v1538
        popj    17,

; Actual DTC request contract AC1=unit, AC2=RBN, AC3=workspace.
dtfs_dtc_read:
        aos     io_count_v1538
        camn    2,test_fail_block_v1538
        jrst    dtfs_dtc_error_v1538
        caie    2,5                     ; EXTENT metadata table RBN
        jrst    dtfs_dtc_data_v1538
        setzm   0(3)
        move    4,[0,,010]             ; one stored block on physical DTC0
        movem   4,1(3)
        move    4,test_extent_v1538    ; STORED 0 or BLOCK 1, one RBN
        lsh     4,022
        iori    4,1
        movem   4,2(3)
        setz    1,
        popj    17,
dtfs_dtc_data_v1538:
        movei   4,0670
        movem   4,(3)
        setz    1,
        popj    17,
dtfs_dtc_error_v1538:
kret_neg1:
        seto    1,
        popj    17,
kret_zero:
        setz    1,
        popj    17,

fs_copy_words:
        jumpe   3,fs_copy_done_v1538
fs_copy_loop_v1538:
        move    4,(1)
        movem   4,(2)
        aoj     1,
        aoj     2,
        sojg    3,fs_copy_loop_v1538
fs_copy_done_v1538:
        setz    1,
        popj    17,

; These are deliberately unreachable on a failed stored/BLOCK DTC read.
mm_alloc:
mm_free:
d6codec_decode_buffer_v1458:
        seto    1,
        popj    17,

        .data
kconst_1_1: .word 1,,1
kconst_7_7: .word 7,,7
vfs_namespace_root: .word 070101000000
test_vnode_v1538: .word 070102000001
test_mode_v1538: .word 0        ; 0 FILE table, 1 file data
test_index_v1538: .word 1
test_count_v1538: .word 1
test_fail_block_v1538: .word 4 ; fail FILE table by default
test_extent_v1538: .word 0     ; STORED 0 / BLOCK 1
test_expected_v1538: .word -1
test_expected_io_v1538: .word 1

dtfs_media_base: .word media_table_v1538
tsfs_extent_media_base: .word extent_table_v1538
tsfs_file_shape_base: .word shape_table_v1538
; Mounted TSFS providers on slot 0 (root) and slot 1 (secondary).
media_table_v1538:
        .word 0700002,,4
        .word 0700002,,4
extent_table_v1538:
        .word 0700001,,5
        .word 0700001,,5
shape_table_v1538:
        .word 0
        .word 0

; TSFS regular file: 1 word, one extent record. No data is fabricated
; on failed I/O; the hardware stub returns a negative result instead.
tsfs_file_v1538:
        .word 2
        .block 4
        .word 1
        .word 0,,1
        .word 0

        .bss
io_count_v1538: .block 1
fs_block_workspace: .block 0200
result_v1538: .block 4
__test_exit: .block 1
