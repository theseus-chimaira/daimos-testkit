; v1544: real D6FS reader and direct DSK/DRM bridge on PDP-6.
; Only final physical device status and BCACHE are test-controlled.
        .text
        .globl  main
        .globl  __test_exit
        .globl  d6fs_reader_get_block
        .globl  d6fs_reader_commit_cache
        .globl  fs_backing_direct_read_jump
        .globl  fs_backing_direct_write_jump
        .globl  fs_backing_direct_drm_read_jump
        .globl  fs_backing_direct_drm_write_jump
        .globl  fs_backing_direct_root_read_call
        .globl  fs_backing_direct_root_write_call
        .globl  fs_backing_direct_root_drm_read_call
        .globl  fs_backing_direct_root_drm_write_call
        .globl  bcache_fetch
        .globl  bcache_store
        .globl  bcache_workspace_invalidate
        .globl  fs_block_workspace
        .globl  vfs_namespace_root
        .globl  kret_zero
        .globl  kret_neg1
        .globl  mfsdev_d6set_reads
        .globl  mfsdev_d6set_writes
        .globl  mfsdev_storage_errors
        .globl  seen_kind_v1544
        .globl  seen_unit_v1544
        .globl  seen_block_v1544
        .globl  read_count_v1544
        .globl  root_error_count_v1544

main:
        ; Simulate MINIT patching exactly the existing adapter jump/call
        ; instruction addresses; no replacement adapter is linked.
        movei   1,dsk_completion_v1544
        hrrm    1,fs_backing_direct_read_jump
        hrrm    1,fs_backing_direct_write_jump
        hrrm    1,fs_backing_direct_root_read_call
        hrrm    1,fs_backing_direct_root_write_call
        movei   1,drm_completion_v1544
        hrrm    1,fs_backing_direct_drm_read_jump
        hrrm    1,fs_backing_direct_drm_write_jump
        hrrm    1,fs_backing_direct_root_drm_read_call
        hrrm    1,fs_backing_direct_root_drm_write_call

        setzm   read_count_v1544
        setzm   store_count_v1544
        move    1,test_reader_v1544
        move    2,test_block_v1544
        skipn   test_write_v1544
        jrst    test_read_v1544
        pushj   17,d6fs_reader_commit_cache
        jrst    test_result_v1544
test_read_v1544:
        pushj   17,d6fs_reader_get_block
test_result_v1544:
        camn    1,test_expected_v1544
        jrst    test_store_v1544
        movei   1,7
        popj    17,
test_store_v1544:
        move    2,store_count_v1544
        camn    2,test_stores_v1544
        jrst    test_pass_v1544
        movei   1,6
        popj    17,
test_pass_v1544:
        setz    1,
        popj    17,

bcache_fetch:
        setz    1,                    ; force actual reader cache miss
        popj    17,
bcache_store:
        aos     store_count_v1544
        setz    1,
        popj    17,
bcache_workspace_invalidate:
        popj    17,                   ; preserves reader address

; Completion stub is strictly BELOW the actual direct-device adapter.
; Store the physical kind/unit/block even on the fatal root path, then
; return the requested exhausted error or completed success.
dsk_completion_v1544:
        movei   5,1
        jrst    physical_completion_v1544
drm_completion_v1544:
        movei   5,2
physical_completion_v1544:
        aos     read_count_v1544
        movem   5,seen_kind_v1544
        movem   1,seen_unit_v1544
        movem   2,seen_block_v1544
        skipn   test_io_failed_v1544
        jrst    physical_success_v1544
kret_neg1:
        seto    1,
        popj    17,
kret_zero:
        setz    1,
        popj    17,
physical_success_v1544:
        movei   4,0670
        movem   4,(3)
        setz    1,
        popj    17,

        .data
vfs_namespace_root: .word 060101000000
test_reader_v1544: .word secondary_reader_v1544
test_block_v1544: .word 5
test_write_v1544: .word 0
test_io_failed_v1544: .word 1
test_expected_v1544: .word 0
test_stores_v1544: .word 0

; Actual 16-word D6FS reader layout (octal). Root marker applies only
; to the boot reader. Secondary handoff uses a distinct physical unit.
root_reader_v1544:
        .word 0
        .word 0101
        .word 0
        .word 0100
        .block 7
        .word fs_backing_direct_read,,fs_backing_direct_write
root_selector_v1544: .word 0100000,,0200
        .word 0100
secondary_reader_v1544:
        .word 0
        .word 0102
        .word 0
        .word 0100
        .block 7
        .word fs_backing_direct_read,,fs_backing_direct_write
secondary_selector_v1544: .word 2,,0100
        .word 0100

        .bss
fs_block_workspace: .block 0200
store_count_v1544: .block 1
read_count_v1544: .block 1
seen_kind_v1544: .block 1
seen_unit_v1544: .block 1
seen_block_v1544: .block 1
mfsdev_d6set_reads: .block 1
mfsdev_d6set_writes: .block 1
mfsdev_storage_errors: .block 4
root_error_count_v1544: .block 1
        .block 1
__test_exit: .block 1
