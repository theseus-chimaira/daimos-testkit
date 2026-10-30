        .text
        .globl main
main:
        movei 17,__stack-1
        hrli 17,-0400
        movei 1,__req_a
        setz 2,
        pushj 17,proc_swap_exchange_tails_v773
        jumpn 1,fail
        move 1,__disk+0400
        caie 1,0123
        jrst fail
        movei 1,0456
        movem 1,__disk+0400
        movei 1,__req_b
        movei 2,1
        pushj 17,proc_swap_exchange_tails_v773
        jumpn 1,fail
        move 1,__b+0400
        caie 1,0456
        jrst fail
        setz 1,
        jrst finish
fail:
        movei 1,1
finish:
        movem 1,__test_exit
        jrst 4,0
        .globl backstore_read
backstore_read:
        lsh 1,7
        move 4,__disk(1)
        movem 4,(3)
        setz 1,
        popj 17,
        .globl backstore_write
backstore_write:
        lsh 1,7
        move 4,(3)
        movem 4,__disk(1)
        setz 1,
        popj 17,
        .data
__req_a: .word 0
        .word __a
        .word __b
        .word 3
        .word 2
__req_b: .word 0
        .word __a
        .word __b
        .word 2
        .word 3
__a: .block 0400
        .word 0123
__disk: .block 0400
        .word 0456
        .bss
__b: .block 0600
        .globl __test_exit
__test_exit: .block 1
__stack: .block 0400
