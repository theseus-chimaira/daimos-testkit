; v1575 actual DTFS provider-private discard lease completion leaf.
; The production assembly is extracted into this source-linked fixture.
; No Type-551 hardware I/O is required after the provider lease drains.
        .text
        .globl main
        .globl dtfs_discard_drain_v1575
        .globl dtfs_cache_mount
        .globl bcache_invalidate_all
        .globl kret_zero
        .globl __test_exit

main:
        movei 1,0246
        movem 1,dtfs_cache_mount
        setzm invalidate_calls_v1575
        movei 1,2                     ; zero-based poisoned mount slot
        pushj 17,dtfs_discard_drain_v1575
        jumpn 1,discard_fail_v1575
        skipn dtfs_cache_mount
        jrst discard_cache_ok_v1575
        jrst discard_fail_v1575
discard_cache_ok_v1575:
        move 1,invalidate_calls_v1575
        caie 1,1
        jrst discard_fail_v1575
        setz 1,
        popj 17,
discard_fail_v1575:
        movei 1,1
        popj 17,

bcache_invalidate_all:
        aos invalidate_calls_v1575
        popj 17,
kret_zero:
        setz 1,
        popj 17,

        .data
dtfs_cache_mount:          .word 0
invalidate_calls_v1575:   .word 0
        .bss
__test_exit:               .block 1
