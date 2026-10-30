        .text
        .globl main
main:
        movei 17,__stack-1
        hrli 17,-0400
        movei 1,1
        movei 2,2
        setz 2,
        pushj 17,proc_storage_expect_v30
        jumpn 1,fail1
        movei 1,2
        movei 2,1
        pushj 17,proc_storage_expect_v30
        jumpn 1,failsecond
        movei 1,1
        movei 2,2
        pushj 17,proc_storage_exchange_modes_v778
        jumpn 1,fail1
        move 1,__modes
        caie 1,5
        jrst fail2
        movei 1,1
        movei 2,2
        pushj 17,proc_storage_exchange_modes_v778
        camn 1,[-1]
        jrst check_unchanged
        jrst fail
check_unchanged:
        move 1,__modes
        caie 1,5
        jrst fail
        movei 1,1
        movei 2,1
        pushj 17,proc_storage_exchange_modes_v778
        camn 1,[-1]
        jrst pass
        jrst fail
pass:
        setz 1,
        jrst finish
failsecond:
        movei 1,7
        jrst finish
fail1:
        movei 1,2
        jrst finish
fail2:
        movei 1,3
        jrst finish
fail:
        movei 1,1
finish:
        movem 1,__test_exit
        jrst 4,0
        .data
        .globl proc_storage_runtime_v29
proc_storage_runtime_v29: .word __modes
        .word 4
__modes: .word 021
        .bss
        .globl __test_exit
__test_exit: .block 1
__stack: .block 0400
