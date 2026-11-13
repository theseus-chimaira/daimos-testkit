; v1541: exercise the real fixed BACKSTORE transfer gateway and v1515 HALT.
; Only disk/drum transport completion is supplied by this native fixture.
        .text
        .globl main
        .globl __test_exit
        .globl backstore_read
        .globl backstore_write
        .globl backstore_enabled
        .globl backstore_blocks_used
        .globl device_region_map
        .globl volume_data_blocks
        .globl backing_region_count
        .globl dsk270_read_sector
        .globl dsk270_write_sector
        .globl drm236_read_block
        .globl drm236_write_block
        .globl kconst_6_6
        .globl kret_zero
        .globl kret_neg1

main:
        setzm   transfer_count_v1541
        skipn   test_write_v1541
        jrst    test_read_v1541
        move    1,test_first_v1541
        move    2,test_blocks_v1541
        move    3,test_buf_v1541
        pushj   17,backstore_write
        jrst    test_result_v1541
test_read_v1541:
        move    1,test_first_v1541
        move    2,test_blocks_v1541
        move    3,test_buf_v1541
        pushj   17,backstore_read
test_result_v1541:
        camn    1,test_expected_v1541
        jrst    test_count_v1541
        movei   1,7
        popj    17,
test_count_v1541:
        move    2,transfer_count_v1541
        camn    2,test_expected_calls_v1541
        jrst    test_pass_v1541
        movei   1,6
        popj    17,
test_pass_v1541:
        setz    1,
        popj    17,

dsk270_read_sector:
drm236_read_block:
        jrst    physical_io_v1541
dsk270_write_sector:
drm236_write_block:
        jrst    physical_io_v1541
physical_io_v1541:
        aos     transfer_count_v1541
        move    0,transfer_count_v1541
        camn    0,test_fail_at_v1541
        jrst    physical_fail_v1541
        movei   0,0670
        movem   0,(3)
        setz    1,
        popj    17,
physical_fail_v1541:
kret_neg1:
        seto    1,
        popj    17,
kret_zero:
        setz    1,
        popj    17,

        .data
test_first_v1541: .word 0
test_blocks_v1541: .word 1
test_buf_v1541: .word transfer_buffer_v1541
test_write_v1541: .word 0
test_fail_at_v1541: .word 1
test_expected_v1541: .word -1
test_expected_calls_v1541: .word 1
test_force_enabled_v1541: .word 1
test_force_zero_v1541: .word 0
backstore_enabled: .word 1
backstore_blocks_used: .word 0
; High half: physical selector. DSK0 default; 0400000 selects DRM0.
device_region_map: .word 0,,010
volume_data_blocks: .word 0
backing_region_count: .word 4
kconst_6_6: .word 6,,6

        .bss
transfer_count_v1541: .block 1
transfer_buffer_v1541: .block 0400
__test_exit: .block 1
