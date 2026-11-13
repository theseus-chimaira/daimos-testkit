; PDP-6 v1538 source-linked D6FS read/write root-versus-secondary oracle.
; The harness instantiates the actual fixed KCORE root gate, D6FS block
; reader/write-through and generic backing dispatch.  Only the low-level
; callback and clean BCACHE service are test-specific.
        .text
        .globl  main
        .globl  __test_exit
        .globl  d6fs_reader_get_block
        .globl  d6fs_reader_commit_cache
        .globl  bcache_fetch
        .globl  bcache_store
        .globl  bcache_workspace_invalidate
        .globl  fs_block_workspace
        .globl  vfs_namespace_root
        .globl  kret_zero
        .globl  kret_neg1

main:
        setzm   store_count_v1538
        setzm   read_count_v1538
        move    1,test_reader_v1538
        move    2,test_block_v1538
        skipn   test_write_v1538
        jrst    test_read_v1538
        pushj   17,d6fs_reader_commit_cache
        jrst    test_result_v1538
test_read_v1538:
        pushj   17,d6fs_reader_get_block
test_result_v1538:
        camn    1,test_expected_v1538
        jrst    test_count_v1538
        movei   1,7
        popj    17,
test_count_v1538:
        move    2,store_count_v1538
        camn    2,test_stores_v1538
        jrst    test_reads_v1538
        movei   1,6
        popj    17,
test_reads_v1538:
        move    2,read_count_v1538
        camn    2,test_io_calls_v1538
        jrst    test_pass_v1538
        movei   1,5
        popj    17,
test_pass_v1538:
        setz    1,
        popj    17,

bcache_fetch:
        setz    1,                      ; force genuine lower-level request
        popj    17,
bcache_store:
        aos     store_count_v1538
        setz    1,
        popj    17,
bcache_workspace_invalidate:
        ; Production invalidation preserves the reader argument in AC1.
        popj    17,
physical_io_v1538:
        aos     read_count_v1538
        skipn   test_io_failed_v1538
        jrst    physical_success_v1538
kret_neg1:
        seto    1,
        popj    17,
kret_zero:
        setz    1,
        popj    17,
physical_success_v1538:
        movei   4,0670
        movem   4,(3)
        setz    1,
        popj    17,

        .data
; The root's actual selected filesystem is D6FS mount 1 by default.
vfs_namespace_root: .word 060101000000
test_reader_v1538: .word root_reader_v1538
test_block_v1538: .word 5
test_write_v1538: .word 0
test_io_failed_v1538: .word 1
test_expected_v1538: .word 0
test_stores_v1538: .word 0
test_io_calls_v1538: .word 1

; D6FS reader word 1: writable flag 0100 and public mount ID 1/2.
; Reader words 013..015 are the complete three-word physical backing.
root_reader_v1538:
        .word 0
        .word 0101
        .word 0
        .word 0100
        .block 7
        .word physical_io_v1538,,physical_io_v1538
        .word 0
        .word 0100
secondary_reader_v1538:
        .word 0
        .word 0102
        .word 0
        .word 0100
        .block 7
        .word physical_io_v1538,,physical_io_v1538
        .word 0
        .word 0100
unmounted_reader_v1538:
        .word 0
        .word 0100
        .word 0
        .word 0100
        .block 7
        .word physical_io_v1538,,physical_io_v1538
        .word 0
        .word 0100

        .bss
fs_block_workspace: .block 0200
store_count_v1538: .block 1
read_count_v1538: .block 1
__test_exit: .block 1
