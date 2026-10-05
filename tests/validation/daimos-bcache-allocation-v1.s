        .text
        .globl  main
        .globl  mm_alloc_aligned_noreclaim
        .globl  mm_free
        .globl  kret_zero
        .globl  kret_one
        .globl  kconst_2_2
        .globl  fs_block_workspace
        .globl  __test_exit

main:
        setzm   alloc_calls
        setzm   free_calls
        movei   1,012345
        movem   1,input_block
        move    1,[01001,,5]
        movei   2,input_block
        pushj   17,bcache_store

        move    1,alloc_calls
        caie    1,1
        jrst    allocation_fail
        move    1,alloc_words
        caie    1,0201
        jrst    allocation_fail
        move    1,alloc_alignment
        caie    1,1
        jrst    allocation_fail
        move    1,alloc_type
        caie    1,3
        jrst    allocation_fail
        move    1,alloc_owner
        caie    1,6
        jrst    allocation_fail
        move    1,alloc_preference
        caie    1,1
        jrst    allocation_fail

        setzm   result_block
        move    1,[01001,,5]
        movei   2,result_block
        pushj   17,bcache_fetch
        caie    1,1
        jrst    allocation_fail
        move    1,result_block
        caie    1,012345
        jrst    allocation_fail

        ; Workspace stores own slot 0 without another data allocation.
        movei   1,054321
        movem   1,fs_block_workspace
        move    1,[01002,,6]
        movei   2,fs_block_workspace
        pushj   17,bcache_store
        move    1,alloc_calls
        caie    1,1
        jrst    allocation_fail
        setzm   result_block
        move    1,[01002,,6]
        movei   2,result_block
        pushj   17,bcache_fetch
        caie    1,1
        jrst    allocation_fail
        move    1,result_block
        caie    1,054321
        jrst    allocation_fail

        pushj   17,bcache_workspace_invalidate
        move    1,[01002,,6]
        movei   2,result_block
        pushj   17,bcache_fetch
        jumpn   1,allocation_fail

        movei   1,1
        pushj   17,bcache_reclaim
        caie    1,1
        jrst    allocation_fail
        move    1,free_calls
        caie    1,1
        jrst    allocation_fail
        move    1,free_base
        caie    1,cache_slab
        jrst    allocation_fail
        move    1,free_type
        caie    1,3
        jrst    allocation_fail
        move    1,free_owner
        caie    1,6
        jrst    allocation_fail

        move    1,[01001,,5]
        movei   2,result_block
        pushj   17,bcache_fetch
        jumpn   1,allocation_fail
        setz    1,
        popj    17,

allocation_fail:
        movei   1,1
        popj    17,

; MM allocation ABI: AC1..AC4 are words/alignment/type/owner.  After PUSHJ,
; caller argument 5 is -1(17), argument 6 (basep) is -2(17).
mm_alloc_aligned_noreclaim:
        aos     alloc_calls
        movem   1,alloc_words
        movem   2,alloc_alignment
        movem   3,alloc_type
        movem   4,alloc_owner
        move    5,-1(17)
        movem   5,alloc_preference
        move    5,-2(17)
        movei   6,cache_slab
        movem   6,(5)
        setz    1,
        popj    17,

mm_free:
        aos     free_calls
        movem   1,free_base
        movem   2,free_type
        movem   3,free_owner
        setz    1,
        popj    17,

kret_zero:
        setz    1,
        popj    17,
kret_one:
        movei   1,1
        popj    17,

        .data
kconst_2_2:
        .word   2,,2

        .bss
alloc_calls:        .block 1
alloc_words:        .block 1
alloc_alignment:    .block 1
alloc_type:         .block 1
alloc_owner:        .block 1
alloc_preference:   .block 1
free_calls:         .block 1
free_base:          .block 1
free_type:          .block 1
free_owner:         .block 1
fs_block_workspace: .block 0200
input_block:        .block 0200
result_block:       .block 0200
cache_slab:         .block 0201
__test_exit:        .block 1
