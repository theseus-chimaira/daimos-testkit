; PDP-6 direct native KCC codec ABI and round-trip smoke regression.
; The source is 8 words: three zeros, three repeated words, two literals.
; Expected encoded stream is six 36-bit words.
        .text
        .globl main
        .globl kpack_ram_measure_v1376
        .globl kpack_ram_encode_v1376
        .globl kpack_ram_decode_v1376
main:
        movei   0,1
        movem   0,stage_v1376
        movei   1,source_v1376
        movei   2,010
        pushj   17,kpack_ram_measure_v1376
        caie    1,6
        jrst    fail_v1376

        movei   0,2
        movem   0,stage_v1376
        movei   1,source_v1376
        movei   2,010
        movei   3,encoded_v1376
        movei   4,6
        pushj   17,kpack_ram_encode_v1376
        caie    1,6
        jrst    fail_v1376

        movei   0,3
        movem   0,stage_v1376
        movei   1,encoded_v1376
        movei   2,6
        movei   3,restored_v1376
        movei   4,010
        pushj   17,kpack_ram_decode_v1376
        caie    1,010
        jrst    fail_v1376

        movei   0,4
        movem   0,stage_v1376
        setz    5,
compare_v1376:
        move    6,source_v1376(5)
        came    6,restored_v1376(5)
        jrst    fail_v1376
        aoj     5,
        caige   5,010
        jrst    compare_v1376

        ; A one-word-short output buffer must fail without touching source.
        movei   0,5
        movem   0,stage_v1376
        movei   1,source_v1376
        movei   2,010
        movei   3,encoded_v1376
        movei   4,5
        pushj   17,kpack_ram_encode_v1376
        came    1,[-1]
        jrst    fail_v1376

        ; A truncated input cannot decode the exact expected image.
        movei   0,6
        movem   0,stage_v1376
        movei   1,encoded_v1376
        movei   2,5
        movei   3,restored_v1376
        movei   4,010
        pushj   17,kpack_ram_decode_v1376
        came    1,[-1]
        jrst    fail_v1376
        setz    1,
        popj    17,
fail_v1376:
        movei   1,1
        popj    17,

        .data
source_v1376:
        .word   0
        .word   0
        .word   0
        .word   052
        .word   052
        .word   052
        .word   01234567
        .word   07654321
        .bss
encoded_v1376:
        .block  010
restored_v1376:
        .block  010
        .globl __test_exit
__test_exit:
        .block  1
        .globl stage_v1376
stage_v1376:
        .block  1
