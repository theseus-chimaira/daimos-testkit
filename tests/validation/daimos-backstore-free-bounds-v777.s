        .text
        .globl main
main:
        movei 17,__stack-1
        hrli 17,-0400
        movei 1,044
        movei 2,2
        pushj 17,backstore_free
        move 1,__bitmap+1
        caie 1,1
        jrst fail
        move 1,backstore_blocks_used
        caie 1,2
        jrst fail
        movei 1,044
        movei 2,1
        pushj 17,backstore_free
        skipn __bitmap+1
        jrst check_count
        jrst fail
check_count:
        move 1,backstore_blocks_used
        caie 1,1
        jrst fail
        setz 1,
        jrst finish
fail:
        movei 1,1
finish:
        movem 1,__test_exit
        jrst 4,0
        .data
        .globl backstore_blocks
backstore_blocks: .word 045
        .globl backstore_blocks_used
backstore_blocks_used: .word 2
        .globl backstore_bitmap
backstore_bitmap: .word __bitmap
__bitmap: .word 1
        .word 1
        .bss
        .globl __test_exit
__test_exit: .block 1
__stack: .block 0400
