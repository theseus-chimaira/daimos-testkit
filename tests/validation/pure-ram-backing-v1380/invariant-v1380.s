; Any unexpected storage-map transition is a kernel invariant violation.
; The test fixture deliberately halts rather than masking it.
        .text
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        halt    .
