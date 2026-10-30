        .text
        .globl main
main:
        movei 17,__stack-1
        hrli 17,-0400
        movei 1,__grow_request
        pushj 17,proc_swap_exchange_mm_v779
        jumpn 1,fail
        move 1,__sequence
        caie 1,012
        jrst fail
        move 1,__owner
        caie 1,2
        jrst fail
        setzm __sequence
        movei 1,__shrink_request
        pushj 17,proc_swap_exchange_mm_v779
        jumpn 1,fail
        move 1,__sequence
        caie 1,023
        jrst failseq
        move 1,__owner
        caie 1,3
        jrst fail
        setz 1,
        jrst done
failseq:
        move 1,__sequence
        jrst done
fail:
        movei 1,1
done:
        movem 1,__test_exit
        jrst 4,0
        .globl mm_process_grow_pinned
mm_process_grow_pinned:
        movei 5,1
        movem 5,__sequence
        setz 1,
        popj 17,
        .globl mm_process_transfer_pinned
mm_process_transfer_pinned:
        move 5,__sequence
        imuli 5,010
        addi 5,2
        movem 5,__sequence
        movem 3,__owner
        setz 1,
        popj 17,
        .globl mm_process_shrink_pinned
mm_process_shrink_pinned:
        move 5,__sequence
        imuli 5,010
        addi 5,3
        movem 5,__sequence
        setz 1,
        popj 17,
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        halt .
        .data
__grow_request: .word 02000
        .word 1
        .word 2
        .word 04000
        .word 06000
__shrink_request: .word 02000
        .word 2
        .word 3
        .word 06000
        .word 04000
        .bss
        .globl __test_exit
__test_exit: .block 1
__sequence: .block 1
__owner: .block 1
__stack: .block 0400
