; v1582: real source-linked BLOCKSET INTERLEAVE mapper + BACKSTORE gateway.
; Only physical controller completions and test configuration are supplied.
        .text
        .globl main
        .globl __test_exit
        .globl volume_tail_configure
        .globl blockset_map_block
        .globl blockset_runtime_service_call
        .globl blockset_boot
        .globl backstore_read
        .globl backstore_write
        .globl dsk270_read_sector
        .globl dsk270_write_sector
        .globl drm236_read_block
        .globl drm236_write_block
        .globl kret_neg1
        .globl kret_zero
        .globl kret_one
        .globl backstore_enabled
        .globl backstore_blocks_used
        .globl device_region_map
        .globl volume_data_blocks
        .globl backing_region_count
        .globl kconst_6_6
        .globl observed_io_v1582
        .globl observed_wrong_v1582
        .globl observed_writes_v1582
        .globl observed_drums_v1582

main:
        setzm   observed_io_v1582
        setzm   observed_wrong_v1582
        setzm   observed_writes_v1582
        setzm   observed_drums_v1582
        ; BLT exactly 012 descriptor words into the original BSET MRES
        ; blockset_boot storage, not a test replacement global symbol.
        move    0,[test_blockset_image_v1582,,blockset_boot]
        blt     0,blockset_boot+011
        ; The genuine exported BSET mapping service is linked at its
        ; actual address, just as production MINIT patches the gateway.
        skipn   test_install_mapper_v1582
        jrst    configure_v1582
        movei   1,blockset_map_block
        hrrm    1,blockset_runtime_service_call
configure_v1582:
        move    1,test_tag_v1582
        setz    2,
        movei   3,0600                 ; 3 members * 0200 data sectors
        movei   4,0300                 ; 3 members * 0100 swap sectors
        pushj   17,volume_tail_configure
        skipn   test_write_v1582
        jrst    read_v1582
        move    1,test_first_v1582
        move    2,test_count_v1582
        movei   3,transfer_buffer_v1582
        pushj   17,backstore_write
        jrst    returned_v1582
read_v1582:
        move    1,test_first_v1582
        move    2,test_count_v1582
        movei   3,transfer_buffer_v1582
        pushj   17,backstore_read
returned_v1582:
        camn    1,test_result_v1582
        jrst    calls_v1582
        movei   1,12
        popj    17,
calls_v1582:
        move    1,observed_io_v1582
        camn    1,test_calls_v1582
        jrst    wrong_v1582
        movei   1,11
        popj    17,
wrong_v1582:
        skipn   observed_wrong_v1582
        jrst    writes_v1582
        movei   1,10
        popj    17,
writes_v1582:
        move    1,observed_writes_v1582
        camn    1,test_writes_v1582
        jrst    drums_v1582
        movei   1,7
        popj    17,
drums_v1582:
        move    1,observed_drums_v1582
        camn    1,test_drums_v1582
        jrst    owner_v1582
        movei   1,6
        popj    17,
owner_v1582:
        move    1,backstore_blocks_used
        camn    1,test_owner_v1582
        jrst    data_v1582
        movei   1,5
        popj    17,
data_v1582:
        ; Each successful READ writes a distinct word into its real
        ; 0200-word destination sector; WRITE leaves it untouched.
        move    1,test_result_v1582
        jumpl   1,success_v1582        ; failed physical read writes no data
        skipn   test_write_v1582
        jrst    data_read_v1582
        move    1,transfer_buffer_v1582
        jumpe   1,success_v1582
        movei   1,4
        popj    17,
data_read_v1582:
        skipn   observed_io_v1582
        jrst    success_v1582
        move    1,transfer_buffer_v1582
        caie    1,0701
        jrst    data_bad_v1582
success_v1582:
        setz    1,
        popj    17,
data_bad_v1582:
        movei   1,3
        popj    17,

dsk270_read_sector:
        setz    4,
        setz    5,
        jrst    physical_v1582
dsk270_write_sector:
        movei   4,1
        setz    5,
        jrst    physical_v1582
drm236_read_block:
        setz    4,
        movei   5,1
        jrst    physical_v1582
drm236_write_block:
        movei   4,1
        movei   5,1

physical_v1582:
        ; Controller receives physical member AC1, block AC2, buffer AC3.
        ; Compare every word of the expected map before honoring failure.
        move    6,observed_io_v1582
        caige   6,6
        jrst    physical_compare_v1582
        aos     observed_wrong_v1582
        jrst    physical_fail_v1582
physical_compare_v1582:
        lsh     6,1
        move    7,expected_map_v1582(6)
        camn    1,7
        jrst    physical_block_v1582
        aos     observed_wrong_v1582
physical_block_v1582:
        move    7,expected_map_v1582+1(6)
        camn    2,7
        jrst    physical_buffer_v1582
        aos     observed_wrong_v1582
physical_buffer_v1582:
        ; Every physical completion must receive its own non-overlapping
        ; 0200-word sector of the caller's original transfer buffer.
        movei   7,transfer_buffer_v1582
        move    0,observed_io_v1582
        lsh     0,7
        add     7,0
        camn    3,7
        jrst    physical_write_v1582
        aos     observed_wrong_v1582
physical_write_v1582:
        camn    4,test_write_v1582
        jrst    physical_drum_v1582
        aos     observed_wrong_v1582
physical_drum_v1582:
        move    7,test_tag_v1582
        jumpe   7,physical_dsk_expected_v1582
        caie    5,1
        aos     observed_wrong_v1582
        jrst    physical_account_v1582
physical_dsk_expected_v1582:
        skipn   5
        jrst    physical_account_v1582
        aos     observed_wrong_v1582
physical_account_v1582:
        skipn   4
        jrst    physical_count_v1582
        aos     observed_writes_v1582
physical_count_v1582:
        skipn   5
        jrst    physical_io_count_v1582
        aos     observed_drums_v1582
physical_io_count_v1582:
        aos     observed_io_v1582
        move    7,observed_io_v1582
        camn    7,test_fail_at_v1582
        jrst    physical_fail_v1582
        skipn   4
        jrst    physical_data_v1582
        setz    1,
        popj    17,
physical_data_v1582:
        movei   7,0700
        add     7,observed_io_v1582
        movem   7,(3)
        setz    1,
        popj    17,
physical_fail_v1582:
kret_neg1:
        seto    1,
        popj    17,
kret_zero:
        setz    1,
        popj    17,
kret_one:
        movei   1,1
        popj    17,

        .data
; Each expected physical pair is member unit, then block in that unit.
; Tail logical 0..5 maps to units 1,2,3,1,2,3 by INTERLEAVE.
expected_map_v1582:
        .word   1
        .word   0300
        .word   2
        .word   0400
        .word   3
        .word   0500
        .word   1
        .word   0301
        .word   2
        .word   0401
        .word   3
        .word   0501
test_install_mapper_v1582: .word 1
test_tag_v1582:            .word 0
test_write_v1582:          .word 0
test_first_v1582:          .word 0
test_count_v1582:          .word 3
test_result_v1582:         .word 0
test_calls_v1582:          .word 3
test_fail_at_v1582:        .word 0
test_writes_v1582:         .word 0
test_drums_v1582:          .word 0
test_owner_v1582:          .word 0300
; True blockset_dispatch.s descriptor (production 3-member INTERLEAVE):
; index0 = members,,tail; index1 = total; index2..5 = units;
; index6..9 = per-member base,,tail-end.
test_blockset_image_v1582:
        .word   3,,0300
        .word   01100
        .word   1
        .word   2
        .word   3
        .word   0
        .word   0100,,0400
        .word   0200,,0500
        .word   0300,,0600
        .word   0
backstore_enabled: .word 1
backstore_blocks_used: .word 0300
device_region_map: .word 0
volume_data_blocks: .word 0
backing_region_count: .word 0
kconst_6_6: .word 6,,6

        .bss
observed_io_v1582: .block 1
observed_wrong_v1582: .block 1
observed_writes_v1582: .block 1
observed_drums_v1582: .block 1
transfer_buffer_v1582: .block 01400
__test_exit: .block 1
