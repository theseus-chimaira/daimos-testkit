        .text
        .globl  main
        .globl  kret_zero
        .globl  kret_one
        .globl  bcache_state
        .globl  fs_block_workspace
        .globl  __test_exit

main:
        ; Same 24-bit block, two source tokens, two independent cache entries.
        movei   1,cache_slab
        hrrm    1,bcache_state
        movei   1,01001                 ; D6FS class + mount 1
        lsh     1,030
        iori    1,5
        movem   1,cache_slab+1
        movei   1,01002                 ; D6FS class + mount 2
        lsh     1,030
        iori    1,5
        movem   1,cache_slab+2
        movei   1,0111
        movem   1,cache_slab+3
        movei   1,0222
        movem   1,cache_slab+0203

        movei   1,01001
        lsh     1,030
        iori    1,5
        movei   2,fs_block_workspace
        pushj   17,bcache_fetch
        caie    1,1
        jrst    cache_fail
        move    1,fs_block_workspace
        caie    1,0111
        jrst    cache_fail

        movei   1,01002
        lsh     1,030
        iori    1,5
        movei   2,fs_block_workspace
        pushj   17,bcache_fetch
        caie    1,1
        jrst    cache_fail
        move    1,fs_block_workspace
        caie    1,0222
        jrst    cache_fail

        movei   1,01003
        lsh     1,030
        iori    1,5
        movei   2,fs_block_workspace
        pushj   17,bcache_fetch
        jumpn   1,cache_fail

        setz    1,
        popj    17,
cache_fail:
        movei   1,1
        popj    17,

kret_zero:
        setz    1,
        popj    17,
kret_one:
        movei   1,1
        popj    17,

        .bss
bcache_state:
        .block  1
fs_block_workspace:
        .block  0200
cache_slab:
        .block  0403
__test_exit:
        .block  1
