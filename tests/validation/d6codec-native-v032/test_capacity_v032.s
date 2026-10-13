; Standalone target test: assembler encoder -> native even-only decoder.
        .text
        .globl main
        .globl d6v032_encode_literals
        .globl d6v032_decode
main:
        movei   1,source
        movei   2,013
        movei   3,encoded
        movei   4,1
        pushj   17,d6v032_encode_literals
        jumpl   1,expected_error
        jrst    error_encode
        move    2,1
        movei   1,encoded
        movei   3,decoded
        movei   4,013
        pushj   17,d6v032_decode
        jumpn   1,error_decode
        movei   5,0
verify:
        move    6,source(5)
        came    6,decoded(5)
        jrst    error_data
        aoj     5,
        caige   5,013
        jrst    verify
        setz    1,
        popj    17,
expected_error:
        setz 1,
        popj 17,
error_encode: movei 1,1
        popj 17,
error_decode: movei 1,2
        popj 17,
error_data: movei 1,3
        popj 17,
        .data
source:
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0123456
        .word 0777777
        .word 0123456701
        .bss
encoded: .block 0100
decoded: .block 013
        .globl __test_exit
__test_exit: .block 1
