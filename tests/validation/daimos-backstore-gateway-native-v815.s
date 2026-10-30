.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 movei 1,0
 movei 2,020
 setz 3,
 movei 4,4
 pushj 17,blockset_direct_configure
 movei 1,1
 movei 2,2
 movei 3,__buffer
 pushj 17,backstore_read
 jumpn 1,fail
 move 1,__buffer
 caie 1,01235
 jrst fail
 move 1,__buffer+0200
 caie 1,01236
 jrst fail
 movei 1,1
 movei 2,2
 movei 3,__buffer
 pushj 17,backstore_write
 jumpn 1,fail
 move 1,__writes
 caie 1,2
 jrst fail
 setz 1,
 jrst done
fail: movei 1,1
done: movem 1,__test_exit
 jrst 4,0
.globl dsk270_read_sector
dsk270_read_sector:
 move 4,2
 subi 4,020
 addi 4,01234
 movem 4,(3)
 setz 1,
 popj 17,
.globl dsk270_write_sector
dsk270_write_sector:
 aos __writes
 setz 1,
 popj 17,
.globl drm236_read_block
drm236_read_block: seto 1,
 popj 17,
.globl drm236_write_block
drm236_write_block: seto 1,
 popj 17,
.globl kret_zero
kret_zero: setz 1,
 popj 17,
.globl kret_neg1
kret_neg1: seto 1,
 popj 17,
.data
.globl kconst_6_6
kconst_6_6: .word 6,,6
.globl device_region_map
device_region_map: .word 0
.globl volume_data_blocks
volume_data_blocks: .word 0
.globl backing_region_count
backing_region_count: .word 0
__buffer: .block 0400
.bss
__writes: .block 1
.globl __test_exit
__test_exit: .block 1
__stack: .block 0400
