; Standalone target test: assembler encoder -> native even-only decoder.
        .text
        .globl main
        .globl d6v041_encode_literals
        .globl d6v041_decode
main:
        movei   1,source
        movei   2,013
        movei   3,encoded
        movei   4,0100
        pushj   17,d6v041_encode_literals
        jumpl   1,error_encode
        caie    1,014
        jrst    error_encode
        move    2,1
        movei   1,encoded
        movei   3,decoded
        movei   4,013
        pushj   17,d6v041_decode
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
error_encode: movei 1,1
        popj 17,
error_decode: movei 1,2
        popj 17,
error_data: movei 1,3
        popj 17,
        .data
source:
        .word 0454
        .word 0455
        .word 0456
        .word 0457
        .word 0460
        .word 0461
        .word 0462
        .word 0463
        .word 0464
        .word 0465
        .word 0466
        .bss
encoded: .block 0100
decoded: .block 013
        .globl __test_exit
__test_exit: .block 1
