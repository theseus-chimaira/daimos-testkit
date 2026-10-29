; Isolated PDP-6 execution of both real swap-out failed-unpin branches.
        .text
        .globl main
main:
        setzm __invariants
        movei 13,02000
        pushj 17,postwrite_unpin_probe
        move 1,__invariants
        caie 1,1
        jrst test_fail
        pushj 17,rollback_unpin_probe
        move 1,__invariants
        caie 1,2
        jrst test_fail
        setz 1,
        popj 17,
test_fail:
        movei 1,1
        popj 17,

        .globl mm_unpin
mm_unpin:
        seto 1,
        popj 17,
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        aos __invariants
        setz 1,
        popj 17,
        .bss
        .globl __test_exit
__test_exit: .block 1
__invariants: .block 1
