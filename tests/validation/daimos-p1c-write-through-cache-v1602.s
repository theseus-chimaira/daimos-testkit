; P1-C v1602: original D6FS write-through and original clean BCACHE.
; Only the final Type-270/236 device completion is controlled here.
; No production cache, provider, adapter or owner logic is replaced.
        .text
        .globl main
        .globl __test_exit
        .globl d6fs_reader_commit_cache
        .globl bcache_store
        .globl bcache_fetch
        .globl bcache_state
        .globl bcache_workspace_tag
        .globl fs_block_workspace
        .globl fs_backing_direct_read_jump
        .globl fs_backing_direct_write_jump
        .globl fs_backing_direct_root_read_call
        .globl fs_backing_direct_root_write_call
        .globl fs_backing_direct_drm_read_jump
        .globl fs_backing_direct_drm_write_jump
        .globl fs_backing_direct_root_drm_read_call
        .globl fs_backing_direct_root_drm_write_call
        .globl kret_zero
        .globl kret_one
        .globl kret_neg1
        .globl vfs_namespace_root
        .globl mfsdev_d6set_reads
        .globl mfsdev_d6set_writes
        .globl mfsdev_storage_errors
        .globl mm_alloc_aligned_noreclaim
        .globl mm_free
        .globl kconst_2_2

main:
        movei   1,dsk_completion_v1602
        hrrm    1,fs_backing_direct_read_jump
        hrrm    1,fs_backing_direct_write_jump
        hrrm    1,fs_backing_direct_root_read_call
        hrrm    1,fs_backing_direct_root_write_call
        movei   1,drm_completion_v1602
        hrrm    1,fs_backing_direct_drm_read_jump
        hrrm    1,fs_backing_direct_drm_write_jump
        hrrm    1,fs_backing_direct_root_drm_read_call
        hrrm    1,fs_backing_direct_root_drm_write_call

        ; The physical KINIT/MM cache lease has already been provisioned.
        ; Preseed its base to avoid a fake MM allocation/reclaim service.
        movei   1,test_slab_v1602
        movem   1,bcache_state
        setom   bcache_workspace_tag
        setom   test_slab_v1602
        move    1,[012345]
        movem   1,fs_block_workspace
        movem   1,fs_block_workspace+0177
        move    1,[076543]
        movem   1,test_private_data_v1602
        movem   1,test_private_data_v1602+0177

        ; Original D6FS clean key: (SOURCE_D6FS | mount ID) << 030
        ; with logical block in the 24-bit low field.
        move    1,test_reader_v1602
        move    2,1(1)
        andi    2,077
        iori    2,01000
        lsh     2,030
        iori    2,5
        movem   2,test_target_key_v1602
        move    1,2
        movei   2,fs_block_workspace
        pushj   17,bcache_store

        movei   1,01001               ; independent root D6FS mount 1
        lsh     1,030
        iori    1,7
        movem   1,test_private_key_v1602
        movei   2,test_private_data_v1602
        pushj   17,bcache_store

        ; The caller has modified the real shared workspace. The old clean
        ; tag is still valid at this point; ORIGINAL D6FS must invalidate
        ; it BEFORE calling the real fs_backing_write adapter.
        move    1,[023456]
        movem   1,fs_block_workspace
        move    1,test_reader_v1602
        movei   2,5
        pushj   17,d6fs_reader_commit_cache
        movem   1,test_result_v1602

        ; Verify exactly one actual selected direct-controller WRITE,
        ; with original adapter/reader routing and prior invalidation.
        move    1,test_io_count_v1602
        caie    1,1
        jrst    test_fail_v1602
        move    1,test_invalidate_observed_v1602
        caie    1,1
        jrst    test_fail_v1602
        move    1,test_io_kind_v1602
        came    1,test_kind_v1602
        jrst    test_fail_v1602
        skipn   test_unexpected_mm_v1602
        jrst    test_dispatch_result_v1602
        jrst    test_fail_v1602
test_dispatch_result_v1602:

        skipn   test_fail_io_v1602
        jrst    test_success_v1602
        move    1,test_result_v1602
        camn    1,[-1]
        jrst    test_failed_cache_v1602
        jrst    test_fail_v1602
test_failed_cache_v1602:
        move    1,bcache_workspace_tag
        camn    1,[-1]
        jrst    test_after_target_v1602
        jrst    test_fail_v1602
test_success_v1602:
        skipn   test_result_v1602
        jrst    test_success_cache_v1602
        jrst    test_fail_v1602
test_success_cache_v1602:
        move    1,bcache_workspace_tag
        came    1,test_target_key_v1602
        jrst    test_fail_v1602
        move    1,test_physical_word_v1602
        camn    1,[023456]
        jrst    test_after_target_v1602
        jrst    test_fail_v1602
test_after_target_v1602:
        ; Independent clean private cache must remain valid, with both
        ; endpoints and all 0200 words unchanged across either result.
        move    1,test_slab_v1602
        came    1,test_private_key_v1602
        jrst    test_fail_v1602
        move    1,test_slab_v1602+1
        camn    1,[076543]
        jrst    test_private_last_v1602
        jrst    test_fail_v1602
test_private_last_v1602:
        move    1,test_slab_v1602+0200
        camn    1,[076543]
        jrst    test_private_compare_v1602
        jrst    test_fail_v1602
test_private_compare_v1602:
        movei   4,test_slab_v1602+1
        movei   5,test_private_data_v1602
        movei   6,0200
test_private_compare_loop_v1602:
        move    1,(4)
        came    1,(5)
        jrst    test_fail_v1602
        aoj     4,
        aoj     5,
        sojg    6,test_private_compare_loop_v1602
test_private_hit_v1602:
        move    1,test_private_key_v1602
        movei   2,test_readback_v1602
        pushj   17,bcache_fetch
        caie    1,1
        jrst    test_fail_v1602
        move    1,test_readback_v1602
        camn    1,[076543]
        jrst    test_private_readback_compare_v1602
        jrst    test_fail_v1602
test_private_readback_compare_v1602:
        movei   4,test_readback_v1602
        movei   5,test_private_data_v1602
        movei   6,0200
test_private_readback_loop_v1602:
        move    1,(4)
        came    1,(5)
        jrst    test_fail_v1602
        aoj     4,
        aoj     5,
        sojg    6,test_private_readback_loop_v1602
test_failed_target_miss_v1602:
        skipn   test_fail_io_v1602
        jrst    test_success_hit_v1602
        move    1,test_target_key_v1602
        movei   2,test_readback_v1602
        pushj   17,bcache_fetch
        jumpe   1,test_finish_v1602
        jrst    test_fail_v1602
test_success_hit_v1602:
        move    1,test_target_key_v1602
        movei   2,test_readback_v1602
        pushj   17,bcache_fetch
        caie    1,1
        jrst    test_fail_v1602
        move    1,test_readback_v1602
        camn    1,[023456]
        jrst    test_finish_v1602
        jrst    test_fail_v1602
test_finish_v1602:
        setz    1,
        popj    17,
test_fail_v1602:
        movei   1,1
        popj    17,

dsk_completion_v1602:
        movei   5,1
        jrst    test_completion_v1602
drm_completion_v1602:
        movei   5,2
test_completion_v1602:
        aos     test_io_count_v1602
        movem   5,test_io_kind_v1602
        move    4,bcache_workspace_tag
        camn    4,[-1]
        aos     test_invalidate_observed_v1602
        skipn   test_fail_io_v1602
        jrst    test_completion_success_v1602
kret_neg1:
        seto    1,
        popj    17,
kret_zero:
        setz    1,
        popj    17,
kret_one:
        movei   1,1
        popj    17,
test_completion_success_v1602:
        move    4,(3)
        movem   4,test_physical_word_v1602
        setz    1,
        popj    17,

; The original BCACHE starts with an already leased MM cache slab.
; A new MM allocation or free in this workload would be a test failure,
; not a simulated success or a replacement for original MM semantics.
mm_alloc_aligned_noreclaim:
mm_free:
        aos     test_unexpected_mm_v1602
        seto    1,
        popj    17,

        .data
kconst_2_2: .word 2,,2
vfs_namespace_root: .word 060101000000
test_reader_v1602: .word secondary_reader_v1602
test_kind_v1602: .word 1
test_fail_io_v1602: .word 1
; A real secondary D6FS mount 2, writable, with direct Type-270 DSK2.
; The v1602 script replaces only the descriptor class for DRM cases.
secondary_reader_v1602:
        .word 0
        .word 0102                  ; writable 0100, public mount 2
        .word 0
        .word 0100
        .block 7
        .word fs_backing_direct_read,,fs_backing_direct_write
secondary_selector_v1602: .word 2,,0100
        .word 0100

        .bss
fs_block_workspace: .block 0200
test_slab_v1602: .block 0201
test_private_data_v1602: .block 0200
test_readback_v1602: .block 0200
test_target_key_v1602: .block 1
test_private_key_v1602: .block 1
test_result_v1602: .block 1
test_io_count_v1602: .block 1
test_io_kind_v1602: .block 1
test_invalidate_observed_v1602: .block 1
test_physical_word_v1602: .block 1
test_unexpected_mm_v1602: .block 1
mfsdev_d6set_reads: .block 1
mfsdev_d6set_writes: .block 1
mfsdev_storage_errors: .block 4
        .block 1
__test_exit: .block 1
