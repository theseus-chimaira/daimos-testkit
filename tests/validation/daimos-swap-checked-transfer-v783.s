        .text
        .globl main
main:
        movei 17,__stack-1
        hrli 17,-0400
        movei 1,__bad
        pushj 17,proc_swap_exchange_checked_v783
        camn 1,[-1]
        jrst check_count
        jrst fail
check_count:
        skipn __calls
        jrst check_good
        jrst fail
check_good:
        movei 1,__overflow
        pushj 17,proc_swap_exchange_checked_v783
        camn 1,[-1]
        jrst check_overflow_no_io
        jrst fail
check_overflow_no_io:
        skipn __calls
        jrst run_good
        jrst fail
run_good:
        movei 1,__good
        pushj 17,proc_swap_exchange_checked_v783
        jumpn 1,fail
        move 1,__calls
        caie 1,1
        jrst fail
        setz 1,
        jrst finish
fail:
        movei 1,1
finish:
        movem 1,__test_exit
        jrst 4,0
        .globl proc_swap_exchange_transfer_v774
proc_swap_exchange_transfer_v774:
        aos __calls
        setz 1,
        popj 17,
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        halt .
        .data
__bad:  .word 0
        .word 02000
        .word 04000
        .word 0
        .word 1
        .word 0
        .word 1
__overflow: .word 0
        .word 0777600
        .word 04000
        .word 2
        .word 1
        .word 0
        .word 1
__good: .word 0
        .word 02000
        .word 04000
        .word 1
        .word 1
        .word 0
        .word 1
        .bss
        .globl __test_exit
__test_exit: .block 1
__calls: .block 1
__stack: .block 0400
