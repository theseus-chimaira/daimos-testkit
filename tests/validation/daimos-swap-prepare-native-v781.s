        .text
        .globl main
main:
        movei 17,__stack-1
        hrli 17,-0400
        movei 1,__req
        pushj 17,proc_swap_exchange_prepare_v781
        camn 1,[-1]
        jrst check
        jrst fail
check:
        move 1,__extended
        caie 1,1
        jrst fail
        move 1,__freed
        caie 1,1
        jrst fail
        skipn __req+010
        jrst check_refusal_v1405
        jrst fail
check_refusal_v1405:
        movei 1,1
        movem 1,__refuse_v1405
        movei 1,prepare_refusal_v1405
        movem 1,__resume_v1405
        movei 1,__req
        pushj 17,proc_swap_exchange_prepare_v781
        jrst fail
prepare_refusal_v1405:
        move 1,__invariant_calls_v1405
        caie 1,1
        jrst fail
        move 1,__req+010
        caie 1,1                       ; still owns extended disk tail
        jrst fail
        jrst pass
pass:
        setz 1,
        jrst finish
fail:
        movei 1,1
finish:
        movem 1,__test_exit
        jrst 4,0
        .globl backstore_extend
backstore_extend:
        aos __extended
        setz 1,
        popj 17,
        .globl backstore_free
backstore_free:
        aos __freed
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
        .globl proc_swap_exchange_prepare_ram_v780
proc_swap_exchange_prepare_ram_v780:
        seto 1,
        popj 17,
        .data
__req:  .word 02000
        .word 1
        .word 2
        .word 04000
        .word 06000
        .word 10
        .word 2
        .word 3
        .word 0
__refuse_v1405: .word 0
__resume_v1405: .word 0
        .globl __invariant_calls_v1405
__invariant_calls_v1405: .word 0
        .bss
        .globl __test_exit
__test_exit: .block 1
__extended: .block 1
__freed: .block 1
__stack: .block 0400
