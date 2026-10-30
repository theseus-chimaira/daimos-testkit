        .text
        .globl main
main:
        movei 17,__stack-1
        hrli 17,-0400
        movei 1,__shrink
        pushj 17,proc_swap_exchange_account_v787
        jumpn 1,fail
        move 1,proc_swap_blocks_used
        caie 1,017
        jrst fail
        move 1,__free_first
        caie 1,014
        jrst fail
        move 1,__free_count
        caie 1,2
        jrst fail
        movei 1,__grow
        pushj 17,proc_swap_exchange_account_v787
        jumpn 1,fail
        move 1,proc_swap_blocks_used
        caie 1,021
        jrst fail
        skipn __grow+3
        jrst pass
fail:   movei 1,1
        jrst done
pass:   setz 1,
done:   movem 1,__test_exit
        jrst 4,0
        .globl backstore_free
backstore_free:
        movem 1,__free_first
        movem 2,__free_count
        popj 17,
        .data
__shrink: .word 010
        .word 6
        .word 4
        .word 0
__grow: .word 010
        .word 4
        .word 6
        .word 1
        .globl proc_swap_blocks_used
proc_swap_blocks_used: .word 021
        .bss
        .globl __test_exit
__test_exit: .block 1
__free_first: .block 1
__free_count: .block 1
__stack: .block 0400
