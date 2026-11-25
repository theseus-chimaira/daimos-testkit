; Real provider selector, media proof, mount/retirement and BCACHE leaves.
; Raw block callback and MM/VFS publication are controlled boundaries.
        .text
        .globl main
main:
        movei   1,reader_root_v1927
        movem   1,reader_slots_v1927
        move    1,[012345670123]
        movem   1,shape_v1927
        move    1,[076543210765]
        movem   1,extent_v1927
        movei   1,0777
        movem   1,media_v1927          ; independent root sentinel
        movei   1,1
        movem   1,fail_case_v1927
        ; Secondary capture must check the physical selected superblock.
        pushj   17,mount_v1927
        jumpn   1,fail_v1927
        move    1,reader_slots_v1927+1
        caie    1,reader_v1927
        jrst    fail_v1927
        move    1,shape_v1927+1
        came    1,[012345670123]
        jrst    fail_v1927
        move    1,extent_v1927+1
        came    1,[076543210765]
        jrst    fail_v1927
        skipn   media_v1927+1
        jrst    mount_ok_v1927
        jrst    fail_v1927
mount_ok_v1927:
        ; Physical proof must refuse each mismatched field, and recover
        ; after returning the original medium. Raw mode 0 is healthy.
        movei   010,1
proof_loop_v1927:
        move    1,010
        addi    1,0100
        movem   1,fail_case_v1927
        movem   010,raw_mode_v1927
        pushj   17,prove_v1927
        jumpge  1,fail_v1927
        skipe   media_v1927+1
        jrst    proof_bad_marked_v1927
        jrst    fail_v1927
proof_bad_marked_v1927:
        move    1,shape_v1927+1
        came    1,[012345670123]
        jrst    fail_v1927
        move    1,extent_v1927+1
        came    1,[076543210765]
        jrst    fail_v1927
        setzm   raw_mode_v1927
        pushj   17,prove_v1927
        jumpn   1,fail_v1927
        skipe   media_v1927+1
        jrst    fail_v1927
        aoj     010,
        caig    010,014                ; 12 fault cases
        jrst    proof_loop_v1927
        ; A refused free must retain reader and both identity halves.
        movei   1,0200
        movem   1,fail_case_v1927
        setom   free_fail_v1927
        pushj   17,d6fs_provider_prepare_unmount
        jumpge  1,fail_v1927
        move    1,reader_slots_v1927+1
        caie    1,reader_v1927
        jrst    fail_v1927
        move    1,shape_v1927+1
        came    1,[012345670123]
        jrst    fail_v1927
        setzm   free_fail_v1927
        pushj   17,d6fs_provider_prepare_unmount
        jumpn   1,fail_v1927
        skipe   reader_slots_v1927+1
        jrst    fail_v1927
        skipe   shape_v1927+1
        jrst    fail_v1927
        skipe   extent_v1927+1
        jrst    fail_v1927
        skipe   media_v1927+1
        jrst    fail_v1927
        move    1,media_v1927
        caie    1,0777
        jrst    fail_v1927
        ; Failed physical mount must free unpublished reader, never
        ; publish a mount or replace another slot's identity.
        movei   1,0201
        movem   1,fail_case_v1927
        setzm   published_v1927
        setzm   freed_v1927
        movei   1,4                    ; bad magic
        movem   1,raw_mode_v1927
        pushj   17,mount_v1927
        jumpge  1,fail_v1927
        skipe   published_v1927
        jrst    fail_v1927
        skipn   freed_v1927
        jrst    fail_v1927
        skipe   reader_slots_v1927+1
        jrst    fail_v1927
        setz    1,
        popj    17,
fail_v1927:
        move    1,fail_case_v1927
        popj    17,
mount_v1927:
        movei   1,handoff_v1927
        move    2,[060101000007]
        movei   3,1
        movei   6,022
        jrst    d6fs_mres_dispatch
prove_v1927:
        ; Force the cache tags to look valid before every raw read.
        movei   1,04444
        movem   1,bcache_workspace_tag
        movem   1,cache_tag_v1927
        move    1,[060201012345]
        movei   6,030
        jrst    d6fs_mres_dispatch
        .globl fs_backing_direct_read
fs_backing_direct_read:
        came    1,[1,,0400]
        jrst    kret_neg1
        caie    2,021                  ; selected B, not A
        jrst    kret_neg1
        caie    3,fs_block_workspace
        jrst    kret_neg1
        aos     raw_reads_v1927
        move    4,bcache_workspace_tag
        came    4,[-1]
        jrst    kret_neg1
        move    4,cache_tag_v1927
        came    4,[-1]
        jrst    kret_neg1
        move    4,raw_mode_v1927
        caie    4,3                    ; false success leaves old workspace
        jrst    raw_copy_v1927
        jrst    kret_zero
raw_copy_v1927:
        caie    4,2                    ; real transfer refusal
        jrst    raw_seed_v1927
        jrst    kret_neg1
raw_seed_v1927:
        move    5,[super_v1927,,fs_block_workspace]
        blt     5,fs_block_workspace+017
        jumpe   4,kret_zero
        cain    4,1
        jrst    raw_high_v1927
        cain    4,014
        jrst    raw_low_v1927
        ; 4..13 change magic, sequence, state and geometry fields.
        move    5,raw_offsets_v1927-4(4)
        aos     fs_block_workspace(5)
        jrst    kret_zero
raw_high_v1927:
        aos     fs_block_workspace+3
        jrst    kret_zero
raw_low_v1927:
        aos     fs_block_workspace+4
        jrst    kret_zero
        .globl fs_backing_direct_write
fs_backing_direct_write:
        jrst    kret_neg1
        .globl mm_alloc
mm_alloc:
        caie    1,016
        jrst    kret_neg1
        move    5,-1(17)
        movei   6,reader_v1927
        movem   6,(5)
        jrst    kret_zero
        .globl mm_free
mm_free:
        caie    1,reader_v1927
        jrst    kret_neg1
        skipn   free_fail_v1927
        jrst    mm_free_ok_v1927
        jrst    kret_neg1
mm_free_ok_v1927:
        aos     freed_v1927
        jrst    kret_zero
        .globl vfs_mount_prevalidated
vfs_mount_prevalidated:
        move    5,-2(17)
        move    6,[060201000003]
        movem   6,(5)
        movei   7,1
        aos     published_v1927
        jrst    kret_zero
        .globl bcache_reclaim
bcache_reclaim:
        jrst    kret_zero
        .globl fs_mres_vector_dispatch
        .globl d6fs_provider_space
        .globl d6fs_provider_toggle_state
        .globl proc_swap_storage_invariant_v30
fs_mres_vector_dispatch:
d6fs_provider_space:
d6fs_provider_toggle_state:
proc_swap_storage_invariant_v30:
        jrst    kret_neg1
        .globl kret_zero
        .globl kret_neg1
kret_zero:
        setz    1,
        popj    17,
kret_neg1:
        seto    1,
        popj    17,
        .data
raw_offsets_v1927:
        .word 0
        .word 1
        .word 2
        .word 7
        .word 010
        .word 011
        .word 012
        .word 013
super_v1927:
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
handoff_v1927:
        .word 7
        .word 0330200
        .word 012
        .word 02000
        .word 3
        .word 040
        .word 010
        .word 060
        .word 2
        .word 020
        .word 021
        .word 044066263602
        .word 1,,0400
        .word 02000
        .globl vfs_mount_limit
vfs_mount_limit: .word 4
        .globl d6fs_reader_slots_base
        .globl dtfs_media_base
        .globl tsfs_file_shape_base
        .globl tsfs_extent_media_base
d6fs_reader_slots_base: .word reader_slots_v1927
dtfs_media_base: .word media_v1927
tsfs_file_shape_base: .word shape_v1927
tsfs_extent_media_base: .word extent_v1927
        .globl d6fs_mres_vector
d6fs_mres_vector: .word 0
        .globl bcache_state
bcache_state: .word cache_tag_v1927
        .globl kconst_1_1
        .globl kconst_2_2
        .globl kconst_3_3
kconst_1_1: .word 1,,1
kconst_2_2: .word 2,,2
kconst_3_3: .word 3,,3
        .bss
        .globl d6fs_active_reader
        .globl fs_block_workspace
        .globl bcache_workspace_tag
        .globl __test_exit
d6fs_active_reader: .block 1
fs_block_workspace: .block 0200
bcache_workspace_tag: .block 1
cache_tag_v1927: .block 1
reader_slots_v1927: .block 4
media_v1927: .block 4
shape_v1927: .block 4
extent_v1927: .block 4
reader_root_v1927: .block 016
reader_v1927: .block 016
raw_mode_v1927: .block 1
raw_reads_v1927: .block 1
fail_case_v1927: .block 1
published_v1927: .block 1
freed_v1927: .block 1
free_fail_v1927: .block 1
__test_exit: .block 1
