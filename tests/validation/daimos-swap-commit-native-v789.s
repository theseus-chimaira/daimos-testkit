        .text
        .globl main
main:
        movei 17,__stack-1
        hrli 17,-0400
        movei 1,__request
        pushj 17,proc_swap_exchange_commit_v789
        jumpn 1,fail
        move 1,__order
        caie 1,012345
        jrst fail
        setz 1,
        jrst done
fail:   movei 1,1
done:   movem 1,__test_exit
        jrst 4,0
        .globl proc_swap_exchange_pure_v785
proc_swap_exchange_pure_v785:
        movei 4,1
        jrst advance
        .globl proc_swap_exchange_mm_v779
proc_swap_exchange_mm_v779:
        movei 4,2
        jrst advance
        .globl proc_swap_exchange_records_v786
proc_swap_exchange_records_v786:
        movei 4,3
        jrst advance
        .globl proc_swap_exchange_account_v787
proc_swap_exchange_account_v787:
        movei 4,4
        jrst advance
        .globl proc_swap_exchange_publish_v788
proc_swap_exchange_publish_v788:
        movei 4,5
advance:
        move 5,__order
        imuli 5,010
        add 5,4
        movem 5,__order
        setz 1,
        popj 17,
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        halt .
        .data
__request: .word 1
        .word 2
        .word 3
        .word 4
        .word 5
        .word 0
        .bss
        .globl __test_exit
__test_exit: .block 1
__order: .block 1
__stack: .block 0400
