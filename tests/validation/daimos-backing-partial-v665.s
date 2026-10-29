; PDP-6 execution of the production multi-block BACKING I/O routine.
        .text
        .globl main
main:
        movei 1,0
        movei 2,0100
        movei 3,4
        pushj 17,device_range_configure
        setzm __calls
        movei 1,0
        movei 2,3
        movei 3,__buffer
        pushj 17,backstore_write
        camn 1,[-1]
        jrst check_calls
        movei 1,1
        popj 17,
check_calls:
        move 1,__calls
        caie 1,2
        jrst fail_count
        setz 1,
        popj 17,
fail_count:
        movei 1,2
        popj 17,

        .globl fs_mres_no_service
        .globl dsk270_read_sector
        .globl dsk270_write_sector
        .globl drm236_read_block
        .globl drm236_write_block
fs_mres_no_service:
        seto 1,
        popj 17,
dsk270_write_sector:
        aos __calls
        move 1,__calls
        caie 1,2
        jrst write_ok
        seto 1,
        popj 17,
write_ok:
        setz 1,
        popj 17,
dsk270_read_sector:
drm236_read_block:
drm236_write_block:
        movei 1,3
        popj 17,

        .bss
        .globl __test_exit
__test_exit: .block 1
__calls: .block 1
__buffer: .block 0600
