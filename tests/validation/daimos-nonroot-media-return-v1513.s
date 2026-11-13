; KCORE v1513: source-linked D6FS non-root I/O failure and recovery.
; No fabricated D6FS success: both the backing dispatch and the
; D6FS read/error/no-cache-store branches are production source.
        .text
        .globl  main
        .globl  d6fs_reader_get_block
        .globl  fs_backing_read
        .globl  __test_exit
        .globl  bcache_fetch
        .globl  bcache_store
        .globl  fs_block_workspace
        .globl  kret_zero
        .globl  kret_neg1
        .globl  vfs_namespace_root

main:
        movei   1,1
        movem   1,stage_v1513
        ; Mount 2 is a secondary D6FS on an independently failed unit.
        ; Two real source-linked reads fail before media returns.
        setzm   media_online_v1513
        setzm   read_count_v1513
        setzm   store_count_v1513
        movei   1,secondary_reader_v1513
        movei   2,5
        pushj   17,d6fs_reader_get_block
        jumpn   1,fail_v1513
        movei   1,secondary_reader_v1513
        movei   2,5
        pushj   17,d6fs_reader_get_block
        jumpn   1,fail_v1513
        move    1,read_count_v1513
        caie    1,2
        jrst    fail_v1513
        skipn   store_count_v1513
        jrst    root_independent_v1513
        jrst    fail_v1513

root_independent_v1513:
        movei   1,2
        movem   1,stage_v1513
        ; The built-in root on mount 1 remains online. Its callback is
        ; independently owned; a secondary failure must not poison it.
        movei   1,root_reader_v1513
        movei   2,4
        pushj   17,d6fs_reader_get_block
        caie    1,fs_block_workspace
        jrst    fail_v1513
        move    1,fs_block_workspace
        caie    1,0670
        jrst    fail_v1513
        move    1,store_count_v1513
        caie    1,1
        jrst    fail_v1513

        ; Device returns. The exact same secondary reader and original
        ; mount identity must now succeed, without a synthetic remount.
        movei   1,3
        movem   1,stage_v1513
        setom   media_online_v1513
        movei   1,secondary_reader_v1513
        movei   2,5
        pushj   17,d6fs_reader_get_block
        caie    1,fs_block_workspace
        jrst    fail_v1513
        move    1,fs_block_workspace
        caie    1,0671
        jrst    fail_v1513
        move    1,store_count_v1513
        caie    1,2
        jrst    fail_v1513

        ; A second disconnection must fail again and must not turn an
        ; earlier successful backing read into a fabricated new hit.
        movei   1,4
        movem   1,stage_v1513
        setzm   media_online_v1513
        movei   1,secondary_reader_v1513
        movei   2,6
        pushj   17,d6fs_reader_get_block
        jumpn   1,fail_v1513
        move    1,store_count_v1513
        caie    1,2
        jrst    fail_v1513
        setom   media_online_v1513
        movei   1,secondary_reader_v1513
        movei   2,6
        pushj   17,d6fs_reader_get_block
        caie    1,fs_block_workspace
        jrst    fail_v1513
        move    1,store_count_v1513
        caie    1,3
        jrst    fail_v1513
        move    1,read_count_v1513
        caie    1,5
        jrst    fail_v1513
        move    1,secondary_reader_v1513+1
        caie    1,2
        jrst    fail_v1513
        move    1,root_reader_v1513+1
        caie    1,1
        jrst    fail_v1513
        setz    1,
        popj    17,
fail_v1513:
        move    1,stage_v1513
        lsh     1,6
        add     1,read_count_v1513
        lsh     1,6
        add     1,store_count_v1513
        lsh     1,6
        add     1,fetch_count_v1513
        popj    17,

; Deliberate cache misses model the first read after each failed I/O.
; This test does not assert recovery from already cached stale media.
bcache_fetch:
        aos     fetch_count_v1513
        setz    1,
        popj    17,
bcache_store:
        aos     store_count_v1513
        setz    1,
        popj    17,

test_root_read_v1513:
        movei   4,0670
        movem   4,(3)
        setz    1,
        popj    17,
test_secondary_read_v1513:
        aos     read_count_v1513
        skipn   media_online_v1513
        jrst    kret_neg1
        movei   4,0671
        movem   4,(3)
        setz    1,
        popj    17,
kret_zero:
        setz    1,
        popj    17,
kret_neg1:
        seto    1,
        popj    17,

        .data
vfs_namespace_root: .word 060101000000
; D6FS reader layout: word 1 mount id, word 3 logical block count,
; words 013..015 are packed fs_backing callbacks, opaque and length.
root_reader_v1513:
        .word 0
        .word 1
        .word 0
        .word 0100
        .block 7
        .word test_root_read_v1513,,test_root_read_v1513
        .word 0
        .word 0100
secondary_reader_v1513:
        .word 0
        .word 2
        .word 0
        .word 0100
        .block 7
        .word test_secondary_read_v1513,,test_secondary_read_v1513
        .word 0
        .word 0100

        .bss
fs_block_workspace: .block 0200
media_online_v1513: .block 1
read_count_v1513: .block 1
store_count_v1513: .block 1
stage_v1513: .block 1
fetch_count_v1513: .block 1
__test_exit: .block 1
