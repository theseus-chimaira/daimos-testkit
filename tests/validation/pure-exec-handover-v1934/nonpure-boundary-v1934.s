; Historical isolated EXEC fixtures encode zero PURE text words.
; Execute the actual hold/release leaves extracted by their runners.
; Any attempted PURE decoding/publication in these fixtures is a
; failed test, not a pretend successful reservation.
        .text
        .globl proc_swap_unpack_backing
proc_swap_unpack_backing:
proc_exec_reserve_v1933:
proc_exec_reserve_bad_v1933:
        jrst    proc_swap_storage_invariant_v30
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        movei   1,0776
        movem   1,__test_exit
        halt    .
        .globl kret_zero
kret_zero:
        setz    1,
        popj    17,
        .bss
        .globl proc_exec_resv_head_v1933
proc_exec_resv_head_v1933: .block 1
