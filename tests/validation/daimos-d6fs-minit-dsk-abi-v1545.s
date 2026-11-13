; v1545: genuine PDP-6 D6FS -> direct adapter -> DSK270 ABI conversion.
; Only the actual MRES hardware callback is simulated. The input must be
; a controller-address word, not the (unit, sector, buffer) public ABI.
        .text
        .globl main
        .globl fs_backing_direct_read
        .globl fs_backing_direct_write
        .globl fs_backing_direct_read_jump
        .globl fs_backing_direct_write_jump
        .globl fs_backing_direct_root_read_call
        .globl fs_backing_direct_root_write_call
        .globl dsk270_read_sector
        .globl dsk270_write_sector
        .globl dsk270_read_call
        .globl dsk270_write_jump
        .globl mfsdev_d6set_reads
        .globl mfsdev_d6set_writes
        .globl mfsdev_storage_errors
        .globl kret_neg1
        .globl __test_exit

main:
        movei   1,dsk270_read_sector
        hrrm    1,fs_backing_direct_read_jump
        hrrm    1,fs_backing_direct_root_read_call
        movei   1,dsk270_write_sector
        hrrm    1,fs_backing_direct_write_jump
        hrrm    1,fs_backing_direct_root_write_call
        movei   1,mres_service_v1545
        hrrm    1,dsk270_read_call
        hrrm    1,dsk270_write_jump

        movei   1,2
        movem   1,test_unit_v1545
        movei   1,0400131
        movem   1,test_encoded_v1545

        ; Secondary DSK0..3 class, selected physical unit 2, block 0105.
        move    1,[2,,0100]
        movei   2,5
        movei   3,block_v1545
        pushj   17,fs_backing_direct_read
        jumpn   1,abi_bad_v1545
        move    1,[2,,0100]
        movei   2,5
        movei   3,block_v1545
        pushj   17,fs_backing_direct_write
        jumpn   1,abi_bad_v1545

        ; Root-marked I/O crosses a separate pair of KINIT-patched sites.
        move    1,[0100002,,0100]
        movei   2,5
        movei   3,block_v1545
        pushj   17,fs_backing_direct_read
        jumpn   1,abi_bad_v1545
        move    1,[0100002,,0100]
        movei   2,5
        movei   3,block_v1545
        pushj   17,fs_backing_direct_write
        jumpn   1,abi_bad_v1545

        move    1,callback_count_v1545
        caie    1,4
        jrst    abi_bad_v1545
        move    1,mfsdev_d6set_reads
        caie    1,1
        jrst    abi_bad_v1545
        move    1,mfsdev_d6set_writes
        caie    1,1
        jrst    abi_bad_v1545
        setz    1,
        popj    17,
abi_bad_v1545:
        movei   1,7
        popj    17,

; MRES contract: AC1 is already Type-270 raw physical address,
; AC2 points at a 128-word buffer. Neither the unit nor the sector
; remains as a separate argument at this layer.
mres_service_v1545:
        aos     callback_count_v1545
        came    1,test_encoded_v1545
        jrst    mres_invalid_v1545
        caie    2,block_v1545
        jrst    mres_invalid_v1545
        setz    1,
        popj    17,
mres_invalid_v1545:
        seto    1,
        popj    17,
kret_neg1:
        seto    1,
        popj    17,

        .data
test_unit_v1545: .word 0
test_encoded_v1545: .word 0
        .bss
block_v1545: .block 0200
callback_count_v1545: .block 1
mfsdev_d6set_reads: .block 1
mfsdev_d6set_writes: .block 1
mfsdev_storage_errors: .block 6
__test_exit: .block 1
