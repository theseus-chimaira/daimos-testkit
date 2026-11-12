; BCACHE + real DTC read/write veneers under a refused MM release.
; The only simulated pieces are MM and the hardware DTC block service.
        .text
        .globl main
        .globl mm_alloc_aligned_noreclaim
        .globl mm_free
        .globl mock_dtc_read_v1490
        .globl mock_dtc_write_v1490
        .globl kret_zero
        .globl kret_one
        .globl kconst_2_2
        .globl fs_block_workspace
        .globl __test_exit

main:
        movei   1,01234
        movem   1,physical_word_v1490
        movei   1,05670
        movem   1,write_block_v1490

        ; A physical read populates the shared workspace cache.
        movei   1,2                     ; nonzero DTC unit exercises AC1
        movei   2,5
        movei   3,fs_block_workspace
        pushj   17,dtfs_dtc_read
        jumpn   1,fail_v1490
        move    1,fs_block_workspace
        caie    1,01234
        jrst    fail_v1490
        move    1,read_calls_v1490
        caie    1,1
        jrst    fail_v1490

        ; A write MUST preserve AC1..AC3 across cache invalidation.
        ; It must not attempt to free the shared cache MM slab.
        movei   1,2
        movei   2,5
        movei   3,write_block_v1490
        pushj   17,dtfs_dtc_write
        jumpn   1,fail_v1490
        move    1,write_calls_v1490
        caie    1,1
        jrst    fail_v1490
        move    1,physical_word_v1490
        caie    1,05670
        jrst    fail_v1490
        skipn   free_calls_v1490
        jrst    verify_written_v1490
        jrst    fail_v1490
verify_written_v1490:
        ; The same DTC block must MISS the invalidated clean cache.
        movei   1,2
        movei   2,5
        movei   3,fs_block_workspace
        pushj   17,dtfs_dtc_read
        jumpn   1,fail_v1490
        move    1,read_calls_v1490
        caie    1,2
        jrst    fail_v1490
        move    1,fs_block_workspace
        caie    1,05670
        jrst    fail_v1490

        ; Insert an independent cached key in the private slot.
        move    1,[02001,,7]
        movei   2,write_block_v1490
        pushj   17,bcache_store
        move    1,cache_slab_v1490
        came    1,[02001,,7]
        jrst    fail_v1490

        ; The first MM free fails.  Reclaim must invalidate both cached
        ; identities WITHOUT discarding the still-owned slab pointer.
        movei   1,1
        pushj   17,bcache_reclaim
        jumpn   1,fail_v1490
        move    1,free_calls_v1490
        caie    1,1
        jrst    fail_v1490
        hrrz    1,bcache_state
        caie    1,cache_slab_v1490
        jrst    fail_v1490
        move    1,bcache_workspace_tag
        came    1,[-1]
        jrst    fail_v1490
        move    1,cache_slab_v1490
        came    1,[-1]
        jrst    fail_v1490
        move    1,[2,,5]
        movei   2,readback_v1490
        pushj   17,bcache_fetch
        jumpn   1,fail_v1490
        move    1,[02001,,7]
        movei   2,readback_v1490
        pushj   17,bcache_fetch
        jumpn   1,fail_v1490

        ; The next MM release succeeds and the owner pointer is cleared.
        movei   1,1
        pushj   17,bcache_reclaim
        caie    1,1
        jrst    fail_v1490
        move    1,free_calls_v1490
        caie    1,2
        jrst    fail_v1490
        skipn   bcache_state
        jrst    pass_v1490
        jrst    fail_v1490
pass_v1490:
        setz    1,
        popj    17,
fail_v1490:
        movei   1,1
        popj    17,

; The MM allocation ABI uses the sixth argument at -2(17).
mm_alloc_aligned_noreclaim:
        aos     alloc_calls_v1490
        move    5,-2(17)
        movei   6,cache_slab_v1490
        movem   6,(5)
        setz    1,
        popj    17,

mm_free:
        aos     free_calls_v1490
        move    1,free_calls_v1490
        caie    1,1
        jrst    mm_free_ok_v1490
        seto    1                      ; temporary MM refusal
        popj    17,
mm_free_ok_v1490:
        setz    1,
        popj    17,

; Exact DTC ABI: AC1 physical unit, AC2 block, AC3 buffer.
mock_dtc_read_v1490:
        aos     read_calls_v1490
        caie    1,2
        jrst    io_bad_v1490
        caie    2,5
        jrst    io_bad_v1490
        caie    3,fs_block_workspace
        jrst    io_bad_v1490
        move    4,physical_word_v1490
        movem   4,(3)
        setz    1,
        popj    17,

mock_dtc_write_v1490:
        aos     write_calls_v1490
        caie    1,2
        jrst    io_bad_v1490
        caie    2,5
        jrst    io_bad_v1490
        caie    3,write_block_v1490
        jrst    io_bad_v1490
        move    4,(3)
        movem   4,physical_word_v1490
        setz    1,
        popj    17,
io_bad_v1490:
        aos     bad_io_calls_v1490
        seto    1,
        popj    17,

kret_zero:
        setz    1,
        popj    17,
kret_one:
        movei   1,1
        popj    17,

        .data
kconst_2_2: .word 2,,2

        .bss
        .globl bcache_state
        .globl bcache_workspace_tag
        .globl dtfs_cache_mount
dtfs_cache_mount: .block 1
alloc_calls_v1490: .block 1
free_calls_v1490: .block 1
read_calls_v1490: .block 1
write_calls_v1490: .block 1
bad_io_calls_v1490: .block 1
physical_word_v1490: .block 1
write_block_v1490: .block 0200
readback_v1490: .block 0200
cache_slab_v1490: .block 0201
fs_block_workspace: .block 0200
__test_exit: .block 1
