        .text
        .globl main
main:
        movei 17,__stack-1
        hrli 17,-0400
        movei 1,__request
        pushj 17,proc_swap_exchange_run_v790
        jumpn 1,fail
        move 1,__order
        caie 1,012
        jrst fail
        setzm __order
        movei 1,1
        movem 1,__reject
        movei 1,__request
        pushj 17,proc_swap_exchange_run_v790
        camn 1,[-1]
        jrst check_reject
        jrst fail
check_reject:
        move 1,__order
        caie 1,1
        jrst fail
        setz 1,
        jrst done
fail:   movei 1,1
done:   movem 1,__test_exit
        jrst 4,0
        .globl proc_swap_exchange_stage_v784
proc_swap_exchange_stage_v784:
        movei 4,1
        movem 4,__order
        skipn __reject
        jrst stage_ok
        seto 1,
        popj 17,
stage_ok:
        setz 1,
        popj 17,
        .globl proc_swap_exchange_commit_v789
proc_swap_exchange_commit_v789:
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
__request: .word 1
        .word 2
        .bss
        .globl __test_exit
__test_exit: .block 1
__order: .block 1
__reject: .block 1
__stack: .block 0400
