; Source-linked PDP-6 regression for BACKSTORE invalid and duplicate frees.
; The three-block allocation crosses a 36-bit bitmap word boundary.
        .text
        .globl main
main:
        movei   17,__stack-1
        hrli    17,-0400

        ; Reject a partly unallocated run, preserving both bitmap words.
        movei   1,043
        movei   2,4
        pushj   17,backstore_free
        jumpe   1,fail                 ; invalid release must report refusal
        pushj   17,check_held
        jumpn   1,fail

        ; Disable allocation only; live owners still need to release blocks.
        setzm   backstore_enabled
        movei   1,043
        movei   2,3
        pushj   17,backstore_free
        jumpn   1,fail                 ; disabled allocation allows cleanup
        pushj   17,check_released
        jumpn   1,fail

        ; Reproduce the same allocation to verify the enabled path too.
        movei   1,1
        movem   1,backstore_enabled
        move    1,[0400000000000]
        movem   1,__bitmap
        movei   1,3
        movem   1,__bitmap+1
        movem   1,backstore_blocks_used
        ; Free the complete allocated run across the bitmap boundary.
        movei   1,043
        movei   2,3
        pushj   17,backstore_free
        jumpn   1,fail                 ; valid release returns zero
        pushj   17,check_released
        jumpn   1,fail

        ; A double free may not decrement used-blocks below zero.
        movei   1,043
        movei   2,3
        pushj   17,backstore_free
        jumpe   1,fail                 ; duplicate release must be rejected
        pushj   17,check_released
        jumpn   1,fail
        jrst    success

check_released:
        skipn   __bitmap
        jrst    check_second_empty
        jrst    check_fail
check_second_empty:
        skipn   __bitmap+1
        jrst    check_zero_count
        jrst    check_fail
check_zero_count:
        skipn   backstore_blocks_used
        jrst    check_release_ok
        jrst    check_fail
check_release_ok:
        setz    1,
        popj    17,

check_held:
        move    1,__bitmap
        came    1,[0400000000000]
        jrst    check_fail
        move    1,__bitmap+1
        caie    1,3
        jrst    check_fail
        move    1,backstore_blocks_used
        caie    1,3
        jrst    check_fail
        setz    1,
        popj    17,
check_fail:
        movei   1,1
        popj    17,
success:
        setz    1,
        jrst    done
fail:
        movei   1,1
done:
        movem   1,__test_exit
        jrst    4,0

        .data
        .globl backstore_bitmap
backstore_bitmap: .word __bitmap
        .globl backstore_blocks
backstore_blocks: .word 0110           ; 72 blocks
        .globl backstore_blocks_used
backstore_blocks_used: .word 3
        .globl backstore_enabled
backstore_enabled: .word 1
__bitmap: .word 0400000000000         ; allocated block 35
        .word 3                       ; allocated blocks 36,37
        .bss
        .globl __test_exit
__test_exit: .block 1
__stack: .block 0400
