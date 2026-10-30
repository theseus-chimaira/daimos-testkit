.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 movei 1,1
 movei 2,3
 pushj 17,backstore_verify_allocated_v795
 jumpn 1,fail
 movei 1,1
 movei 2,4
 pushj 17,backstore_verify_allocated_v795
 camn 1,[-1]
 jrst check_bounds
 jrst fail
check_bounds:
 movei 1,044
 movei 2,1
 pushj 17,backstore_verify_allocated_v795
 camn 1,[-1]
 jrst pass
 jrst fail
pass: setz 1,
 jrst done
fail: movei 1,1
done: movem 1,__test_exit
 jrst 4,0
.data
.globl backstore_bitmap
backstore_bitmap: .word __bitmap
.globl backstore_blocks
backstore_blocks: .word 044
.globl backstore_enabled
backstore_enabled: .word 1
__bitmap: .word 016
.bss
.globl __test_exit
__test_exit: .block 1
__stack: .block 0400
