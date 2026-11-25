; Historical isolated mount oracle: controlled physical header read.
; Actual backing dispatch/cache behavior is tested in test-native-v1927.
        .text
        .globl fs_backing_read
        .globl bcache_invalidate_all
        .globl proc_swap_storage_invariant_v30
fs_backing_read:
        caie    2,021
        jrst    kret_neg1
        caie    3,fs_block_workspace
        jrst    kret_neg1
        move    4,[super_fixture_v1927,,fs_block_workspace]
        blt     4,fs_block_workspace+017
        setz    1,
        popj    17,
bcache_invalidate_all:
        popj    17,
proc_swap_storage_invariant_v30:
        jrst    kret_neg1
        .data
super_fixture_v1927:
        .word 044066263602
        .word 012
        .word 0
        .word 012345670123
        .word 076543210765
        .word 0
        .word 0
        .word 02000
        .word 3
        .word 040
        .word 010
        .word 060
        .word 2
        .word 033
        .word 1
        .word 0
        .globl dtfs_media_base
        .globl tsfs_file_shape_base
        .globl tsfs_extent_media_base
dtfs_media_base: .word uuid_media_v1927
tsfs_file_shape_base: .word uuid_shape_v1927
tsfs_extent_media_base: .word uuid_extent_v1927
        .bss
        .globl fs_block_workspace
        .globl uuid_shape_v1927
        .globl uuid_extent_v1927
fs_block_workspace: .block 0200
uuid_media_v1927: .block 4
uuid_shape_v1927: .block 4
uuid_extent_v1927: .block 4

; This isolated mount fixture has no allocated private BCACHE slab.
        .data
        .globl bcache_state
bcache_state: .word 0
        .text
        .globl bcache_workspace_invalidate
bcache_workspace_invalidate:
        popj    17,

        .text
        .globl d6fs_discard_v1939
d6fs_discard_v1939:
        jrst    kret_neg1
