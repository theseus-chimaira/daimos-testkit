        .text
        .globl main
main:
        movei 17,__stack-1
        hrli 17,-0400
        movei 1,__pair
        pushj 17,proc_swap_exchange_stage_v784
        jumpn 1,fail
        move 1,__prepared
        caie 1,1
        jrst fail
        move 1,__transferred
        caie 1,1
        jrst fail
        movei 1,2
        movem 1,__reject
        movei 1,__pair
        pushj 17,proc_swap_exchange_stage_v784
        camn 1,[-1]
        jrst test_cancel
        jrst fail
test_cancel:
        move 1,__canceled
        caie 1,1
        jrst fail
        movei 1,5
        movem 1,__transfer+4
        movei 1,__pair
        pushj 17,proc_swap_exchange_stage_v784
        camn 1,[-1]
        jrst test_unchanged
        jrst fail
test_unchanged:
        move 1,__prepared
        caie 1,2
        jrst fail
        setz 1,
        jrst done
fail:   movei 1,1
done:   movem 1,__test_exit
        jrst 4,0
        .globl proc_swap_exchange_prepare_v781
proc_swap_exchange_prepare_v781:
        aos __prepared
        setz 1,
        popj 17,
        .globl proc_swap_exchange_checked_v783
proc_swap_exchange_checked_v783:
        aos __transferred
        skipn __reject
        jrst ok
        seto 1,
        popj 17,
ok:     setz 1,
        popj 17,
        .globl proc_swap_exchange_cancel_v782
proc_swap_exchange_cancel_v782:
        aos __canceled
        setz 1,
        popj 17,
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        halt .
        .data
__pair: .word __prep
        .word __transfer
__prep: .word 02000
        .word 1
        .word 2
        .word 04000
        .word 06000
        .word 10
        .word 2
        .word 3
        .word 0
__transfer: .word 10
        .word 02000
        .word 02200
        .word 3
        .word 2
        .word 0
        .word 1
        .bss
        .globl __test_exit
__test_exit: .block 1
__prepared: .block 1
__transferred: .block 1
__canceled: .block 1
__reject: .block 1
__stack: .block 0400
