        .text
        .globl main
main:
        movei 17,__stack-1
        hrli 17,-0400
        movei 1,__req
        pushj 17,proc_swap_exchange_cancel_v782
        jumpn 1,fail
        move 1,__shrunk
        caie 1,1
        jrst fail
        move 1,__freed
        caie 1,1
        jrst fail
        skipn __req+010
        jrst pass
fail:
        movei 1,1
        jrst finish
pass:
        setz 1,
finish:
        movem 1,__test_exit
        jrst 4,0
        .globl mm_process_shrink_pinned
mm_process_shrink_pinned:
        aos __shrunk
        setz 1,
        popj 17,
        .globl backstore_free
backstore_free:
        aos __freed
        popj 17,
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        halt .
        .data
__req:  .word 02000
        .word 1
        .word 2
        .word 04000
        .word 06000
        .word 10
        .word 2
        .word 3
        .word 1
        .bss
        .globl __test_exit
__test_exit: .block 1
__shrunk: .block 1
__freed: .block 1
__stack: .block 0400
