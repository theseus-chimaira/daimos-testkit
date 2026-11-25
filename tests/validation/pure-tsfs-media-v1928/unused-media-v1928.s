; Historical stored-extent fixtures do not invoke private media proof.
; Fail on unexpected raw I/O; actual raw callback/cache proof is covered
; by the v1928 source-linked native gate, not by this fixture.
        .text
        .globl dtfs_dtc_read_jump
        .globl bcache_invalidate_all
dtfs_dtc_read_jump:
bcache_invalidate_all:
        halt .
        .bss
        .globl dtfs_cache_mount
dtfs_cache_mount: .block 1
