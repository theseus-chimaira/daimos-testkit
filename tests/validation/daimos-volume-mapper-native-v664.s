; Native PDP-6 test of the production BACKING transfer gateway.
        .text
        .globl main
main:
        ; Configure multi-member VOLUME, then leave mapper uninstalled.
        movei 1,0
        movei 2,0200
        movei 3,0400
        movei 4,010
        pushj 17,volume_tail_configure
        setzm __device_calls
        movei 1,0
        movei 2,1
        movei 3,__buffer
        pushj 17,backstore_read
        camn 1,[-1]
        jrst v664_check_no_calls
        movei 1,1
        popj 17,
v664_check_no_calls:
        skipn __device_calls
        jrst v664_direct
        movei 1,2
        popj 17,
v664_direct:
        ; Same uninstalled mapper must not block a direct DEVICE region.
        movei 1,0
        movei 2,0200
        movei 3,010
        pushj 17,device_range_configure
        movei 1,0
        movei 2,1
        movei 3,__buffer
        pushj 17,backstore_read
        jumpn 1,v664_direct_fail
        move 1,__device_calls
        caie 1,1
        jrst v664_direct_fail
        setz 1,
        popj 17,
v664_direct_fail:
        movei 1,3
        popj 17,

        .globl fs_mres_no_service
        .globl dsk270_read_sector
        .globl dsk270_write_sector
        .globl drm236_read_block
        .globl drm236_write_block
fs_mres_no_service:
        seto 1,
        popj 17,
dsk270_read_sector:
        aos __device_calls
        setz 1,
        popj 17,
dsk270_write_sector:
drm236_read_block:
drm236_write_block:
        aos __device_calls
        setz 1,
        popj 17,
        .bss
        .globl __test_exit
__test_exit: .block 1
__device_calls: .block 1
__buffer: .block 0200
