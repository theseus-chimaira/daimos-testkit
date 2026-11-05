; E09: real PDP-6 bitmap allocator, genuine finite backing exhaustion.
; No return codes are synthesized. Every occupied block is allocated
; through production backstore_alloc, then checked and freed normally.
        .text
        .globl main
main:
        movei   17,__stack-1
        hrli    17,-0400
        setzm   __bitmap
        movei   1,__bitmap
        movei   2,014                  ; 12 real backing blocks
        pushj   17,backstore_init
        setom   backstore_enabled

        movei   1,5
        movei   2,1                    ; preserve 1-block reserve
        movei   3,__first_a
        pushj   17,backstore_alloc
        jumpn   1,fail_1
        skipn   __first_a
        jrst    alloc_b
        jrst    fail_2
alloc_b:
        movei   1,6
        movei   2,1
        movei   3,__first_b
        pushj   17,backstore_alloc
        jumpn   1,fail_3
        move    1,__first_b
        caie    1,5
        jrst    fail_4
        move    1,backstore_blocks_used
        caie    1,013                  ; 11 allocated
        jrst    fail_5
        move    1,__bitmap
        caie    1,03777                ; exactly bits 0..10
        jrst    fail_6

        ; No capacity remains beyond reserve. A failed allocation must
        ; not change bitmap, allocated count or destination pointer.
        movei   1,1
        movei   2,1
        movei   3,__refusal_target
        pushj   17,backstore_alloc
        camn    1,[-1]
        jrst    check_reserve
        jrst    fail_7
check_reserve:
        move    1,__refusal_target
        caie    1,012345
        jrst    fail_8
        move    1,backstore_blocks_used
        caie    1,013
        jrst    fail_9
        move    1,__bitmap
        caie    1,03777
        jrst    fail_10

        ; With no reserve the final physical block really is free.
        movei   1,1
        setz    2,
        movei   3,__last
        pushj   17,backstore_alloc
        jumpn   1,fail_11
        move    1,__last
        caie    1,013
        jrst    fail_12
        move    1,__bitmap
        caie    1,07777                ; all 12 backing bits set
        jrst    fail_13
        move    1,backstore_blocks_used
        caie    1,014
        jrst    fail_14

        ; The real full bitmap must reject another allocation even
        ; when no reserve is requested.
        movei   1,1
        setz    2,
        movei   3,__refusal_target
        pushj   17,backstore_alloc
        camn    1,[-1]
        jrst    free_middle
        jrst    fail_15
free_middle:
        movei   1,5
        movei   2,6
        pushj   17,backstore_free
        move    1,backstore_blocks_used
        caie    1,6
        jrst    fail_16
        ; Reallocation uses the actual six freed bitmap bits, not a
        ; fabricated success. First fit must return the same span.
        movei   1,6
        setz    2,
        movei   3,__reallocated
        pushj   17,backstore_alloc
        jumpn   1,fail_17
        move    1,__reallocated
        caie    1,5
        jrst    fail_18
        move    1,__bitmap
        caie    1,07777
        jrst    fail_19

        ; All 12 allocated blocks are contiguous again; return the
        ; whole extent and prove both counters and bitmap are empty.
        setz    1,
        movei   2,014
        pushj   17,backstore_free
        skipn   backstore_blocks_used
        jrst    check_empty_bitmap
        jrst    fail_20
check_empty_bitmap:
        skipn   __bitmap
        jrst    pass
        jrst    fail_21
pass:
        setz    1,
        jrst    done
fail_1: movei 1,1
        jrst done
fail_2: movei 1,2
        jrst done
fail_3: movei 1,3
        jrst done
fail_4: movei 1,4
        jrst done
fail_5: movei 1,5
        jrst done
fail_6: movei 1,6
        jrst done
fail_7: movei 1,7
        jrst done
fail_8: movei 1,010
        jrst done
fail_9: movei 1,011
        jrst done
fail_10: movei 1,012
        jrst done
fail_11: movei 1,013
        jrst done
fail_12: movei 1,014
        jrst done
fail_13: movei 1,015
        jrst done
fail_14: movei 1,016
        jrst done
fail_15: movei 1,017
        jrst done
fail_16: movei 1,020
        jrst done
fail_17: movei 1,021
        jrst done
fail_18: movei 1,022
        jrst done
fail_19: movei 1,023
        jrst done
fail_20: movei 1,024
        jrst done
fail_21: movei 1,025
done:
        movem   1,__test_exit
        jrst    4,0

        .data
__bitmap: .word 0
__first_a: .word -1
__first_b: .word -1
__last: .word -1
__reallocated: .word -1
__refusal_target: .word 012345
        .bss
__stack: .block 0400
        .globl __test_exit
__test_exit: .block 1
