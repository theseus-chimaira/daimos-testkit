        .text
        .globl main
main:
        movei 17,__stack-1
        hrli 17,-0400
        movei 1,4
        movei 2,2
        movei 3,4
        pushj 17,backstore_extend
        jumpn 1,fail
        move 1,backstore_blocks_used
        caie 1,6
        jrst fail
        move 1,__bitmap
        caie 1,0760
        jrst fail
        movei 1,4
        movei 2,4
        movei 3,5
        pushj 17,backstore_extend
        camn 1,[-1]
        jrst rejected
        jrst fail
rejected:
        move 1,__bitmap
        caie 1,0760
        jrst fail
        move 1,backstore_blocks_used
        caie 1,6
        jrst fail
        setz 1,
        jrst finish
fail:
        movei 1,1
finish:
        movem 1,__test_exit
        jrst 4,0
        .data
        .globl backstore_enabled
backstore_enabled: .word 1
        .globl backstore_blocks
backstore_blocks: .word 044
        .globl backstore_blocks_used
backstore_blocks_used: .word 4
        .globl backstore_bitmap
backstore_bitmap: .word __bitmap
__bitmap: .word 0460
        .bss
        .globl __test_exit
__test_exit: .block 1
__stack: .block 0400
