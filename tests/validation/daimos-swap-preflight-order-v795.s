        .text
        .globl main
main:   movei 17,__stack-1
        hrli 17,-0400
        movei 1,__request
        pushj 17,proc_swap_exchange_run_v790
        camn 1,[-1]
        jrst check
        jrst fail
check:  move 1,__preflight
        caie 1,1
        jrst fail
        skipn __live
        jrst pass
fail:   movei 1,1
        jrst finish
pass:   setz 1,
finish: movem 1,__test_exit
        jrst 4,0
        .globl proc_swap_exchange_preflight_v791
proc_swap_exchange_preflight_v791:
        aos __preflight
        seto 1,
        popj 17,
        .globl proc_swap_exchange_live_v794
proc_swap_exchange_live_v794:
        aos __live
        seto 1,
        popj 17,
        .globl proc_swap_exchange_stage_v784
proc_swap_exchange_stage_v784:
        halt .
        .globl proc_swap_exchange_commit_v789
proc_swap_exchange_commit_v789:
        halt .
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        halt .
        .data
__request: .word 0
        .word 0
        .bss
        .globl __test_exit
__test_exit: .block 1
__preflight: .block 1
__live: .block 1
__stack: .block 0400
