; v1546: actual D6FS and BACKSTORE service source under one physical owner.
; Only bottom-of-stack controller completion and BCACHE are test-controlled.
        .text
        .globl main
        .globl __test_exit
        .globl d6fs_reader_get_block
        .globl backstore_read
        .globl fs_backing_direct_read_jump
        .globl fs_backing_direct_write_jump
        .globl fs_backing_direct_drm_read_jump
        .globl fs_backing_direct_drm_write_jump
        .globl fs_backing_direct_root_read_call
        .globl fs_backing_direct_root_write_call
        .globl fs_backing_direct_root_drm_read_call
        .globl fs_backing_direct_root_drm_write_call
        .globl dsk270_read_sector
        .globl dsk270_write_sector
        .globl drm236_read_block
        .globl drm236_write_block
        .globl blockset_runtime_service_call
        .globl backstore_enabled
        .globl backstore_blocks_used
        .globl device_region_map
        .globl volume_data_blocks
        .globl backing_region_count
        .globl kconst_6_6
        .globl vfs_namespace_root
        .globl fs_block_workspace
        .globl mfsdev_storage_errors
        .globl mfsdev_d6set_reads
        .globl mfsdev_d6set_writes
        .globl kret_neg1
        .globl kret_zero
        .globl root_calls_v1546
        .globl swap_calls_v1546
        .globl transfer_count_v1546
        .globl bcache_fetch
        .globl bcache_store
        .globl bcache_workspace_invalidate

main:
        movei   1,physical_io_v1546
        hrrm    1,fs_backing_direct_read_jump
        hrrm    1,fs_backing_direct_write_jump
        hrrm    1,fs_backing_direct_drm_read_jump
        hrrm    1,fs_backing_direct_drm_write_jump
        hrrm    1,fs_backing_direct_root_read_call
        hrrm    1,fs_backing_direct_root_write_call
        hrrm    1,fs_backing_direct_root_drm_read_call
        hrrm    1,fs_backing_direct_root_drm_write_call
        movei   1,mapper_v1546
        hrrm    1,blockset_runtime_service_call
        setzm   transfer_count_v1546
        setzm   root_calls_v1546
        setzm   swap_calls_v1546
        setzm   error_count_v1546
        skipn   test_order_v1546
        jrst    root_first_v1546
        pushj   17,swap_io_v1546
        ; Reaching here means a failed BACKSTORE was not classified fatal.
        camn    1,test_swap_result_v1546
        jrst    root_after_swap_v1546
        movei   1,7
        popj    17,
root_after_swap_v1546:
        pushj   17,root_io_v1546
        jrst    result_v1546
root_first_v1546:
        pushj   17,root_io_v1546
        camn    1,test_root_result_v1546
        jrst    swap_after_root_v1546
        movei   1,6
        popj    17,
swap_after_root_v1546:
        pushj   17,swap_io_v1546
result_v1546:
        move    2,root_calls_v1546
        camn    2,test_root_calls_v1546
        jrst    result_swap_count_v1546
        movei   1,5
        popj    17,
result_swap_count_v1546:
        move    2,swap_calls_v1546
        camn    2,test_swap_calls_v1546
        jrst    result_owner_v1546
        movei   1,4
        popj    17,
result_owner_v1546:
        move    2,backstore_blocks_used
        camn    2,test_owner_v1546
        jrst    result_pass_v1546
        movei   1,3
        popj    17,
result_pass_v1546:
        setz    1,
        popj    17,

root_io_v1546:
        aos     root_calls_v1546
        movei   1,1
        movem   1,active_owner_v1546
        movei   1,root_reader_v1546
        movei   2,5
        pushj   17,d6fs_reader_get_block
        popj    17,
swap_io_v1546:
        aos     swap_calls_v1546
        movei   1,2
        movem   1,active_owner_v1546
        setz    1,
        movei   2,1
        movei   3,swap_buffer_v1546
        pushj   17,backstore_read
        popj    17,

; All device classes and the shared mapped VOLUME reach this one
; controller outcome. This is not an alternative error-classifier.
dsk270_read_sector:
dsk270_write_sector:
drm236_read_block:
drm236_write_block:
physical_io_v1546:
        aos     transfer_count_v1546
        move    0,active_owner_v1546
        caie    0,1
        jrst    physical_swap_v1546
        skipn   test_root_fail_v1546
        jrst    physical_ok_v1546
        jrst    physical_error_v1546
physical_swap_v1546:
        skipn   test_swap_fail_v1546
        jrst    physical_ok_v1546
physical_error_v1546:
        aos     error_count_v1546
kret_neg1:
        seto    1,
        popj    17,
physical_ok_v1546:
        setz    1,
        popj    17,
kret_zero:
        setz    1,
        popj    17,

; Mapper contract: AC1=logical data+tail address, AC2=read/write,
; returns physical unit/block for the common real device transfer.
mapper_v1546:
        skipn   test_mapper_fail_v1546
        jrst    mapper_ok_v1546
        seto    1,
        popj    17,
mapper_ok_v1546:
        movei   2,020
        movei   1,0
        popj    17,
bcache_fetch:
        setz    1,
        popj    17,
bcache_store:
        setz    1,
        popj    17,
bcache_workspace_invalidate:
        popj    17,

        .data
vfs_namespace_root: .word 060101000000
; Selected boot D6FS, mount 1, same Type-270 unit 0 as BACKSTORE.
root_reader_v1546:
        .word 0
        .word 0101
        .word 0
        .word 0100
        .block 7
        .word fs_backing_direct_read,,fs_backing_direct_write
root_selector_v1546: .word 0100000,,0200
        .word 0100
test_order_v1546: .word 0
test_root_fail_v1546: .word 1
test_swap_fail_v1546: .word 1
test_mapper_fail_v1546: .word 0
test_force_zero_v1546: .word 0
test_root_result_v1546: .word fs_block_workspace
test_swap_result_v1546: .word 0
test_root_calls_v1546: .word 1
test_swap_calls_v1546: .word 1
test_owner_v1546: .word 0320
backstore_enabled: .word 1
backstore_blocks_used: .word 0320
device_region_map: .word 0,,010
volume_data_blocks: .word 0
backing_region_count: .word 4
kconst_6_6: .word 6,,6

        .bss
active_owner_v1546: .block 1
root_calls_v1546: .block 1
swap_calls_v1546: .block 1
transfer_count_v1546: .block 1
error_count_v1546: .block 1
fs_block_workspace: .block 0200
swap_buffer_v1546: .block 0200
mfsdev_storage_errors: .block 6
mfsdev_d6set_reads: .block 1
mfsdev_d6set_writes: .block 1
__test_exit: .block 1
