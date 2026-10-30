        .text
        .globl main
main:
        movei 17,__stack-1
        hrli 17,-0400
        movei 1,__req
        pushj 17,proc_swap_exchange_publish_v788
        jumpn 1,fail
        move 1,__order
        caie 1,012
        jrst fail
        move 1,__a
        trne 1,0200000
        jrst fail
        move 1,__b
        trne 1,0200000
        jrst fail
        setz 1,
        jrst done
fail:   movei 1,1
done:   movem 1,__test_exit
        jrst 4,0
        .globl mm_unpin
mm_unpin:
        movei 4,1
        movem 4,__order
        setz 1,
        popj 17,
        .globl proc_storage_exchange_modes_v778
proc_storage_exchange_modes_v778:
        move 4,__order
        imuli 4,010
        addi 4,2
        movem 4,__order
        setz 1,
        popj 17,
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        halt .
        .data
__req:  .word __a
        .word __b
        .word 1
        .word 2
        .word 02000
__a:    .word 0200000
__b:    .word 0200000
        .bss
        .globl __test_exit
__test_exit: .block 1
__order: .block 1
__stack: .block 0400
