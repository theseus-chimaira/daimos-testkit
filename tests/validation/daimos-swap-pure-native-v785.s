        .text
        .globl main
main:
        movei 17,__stack-1
        hrli 17,-0400
        movei 1,__request
        pushj 17,proc_swap_exchange_pure_v785
        jumpn 1,fail
        move 1,__sequence
        caie 1,012
        jrst fail
        setzm __sequence
        movei 1,__empty
        pushj 17,proc_swap_exchange_pure_v785
        jumpn 1,fail
        skipn __sequence
        jrst pass
fail:   movei 1,1
        jrst done
pass:   setz 1,
done:   movem 1,__test_exit
        jrst 4,0
        .globl fs_zero_words
fs_zero_words:
        movei 4,1
        movem 4,__sequence
        setz 1,
        popj 17,
        .globl proc_swap_reload_pure
proc_swap_reload_pure:
        move 4,__sequence
        imuli 4,010
        addi 4,2
        movem 4,__sequence
        setz 1,
        popj 17,
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        halt .
        .data
__request: .word 01234
        .word 02000
        .word 03000
        .word 0200
__empty: .word 0
        .word 02000
        .word 03000
        .word 0
        .bss
        .globl __test_exit
__test_exit: .block 1
__sequence: .block 1
__stack: .block 0400
