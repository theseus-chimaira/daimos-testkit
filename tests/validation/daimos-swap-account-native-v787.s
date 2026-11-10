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
        jrst check_refusal_v1405
        jrst fail
check_refusal_v1405:
        movei 1,1
        movem 1,__refuse_v1405
        movei 1,account_refusal_v1405
        movem 1,__resume_v1405
        movei 1,__shrink
        pushj 17,proc_swap_exchange_account_v787
        jrst fail                       ; refused tail cannot return
account_refusal_v1405:
        move 1,__invariant_calls_v1405
        caie 1,1
        jrst fail
        move 1,proc_swap_blocks_used
        caie 1,021                     ; no false accounting delta
        jrst fail
        skipn __shrink+3
        jrst pass
        jrst fail
fail:   movei 1,1
        jrst done
pass:   setz 1,
done:   movem 1,__test_exit
        jrst 4,0
        .globl backstore_free
backstore_free:
        movem 1,__free_first
        movem 2,__free_count
        skipn __refuse_v1405
        jrst free_ok_v1405
        seto 1,
        popj 17,
free_ok_v1405:
        setz 1,
        popj 17,
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        aos __invariant_calls_v1405
        jrst @__resume_v1405
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
__refuse_v1405: .word 0
__resume_v1405: .word 0
        .globl __invariant_calls_v1405
__invariant_calls_v1405: .word 0
        .bss
        .globl __test_exit
__test_exit: .block 1
__free_first: .block 1
__free_count: .block 1
__stack: .block 0400
