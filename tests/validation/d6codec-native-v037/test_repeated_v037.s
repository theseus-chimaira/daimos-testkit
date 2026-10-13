; Standalone target test: assembler encoder -> native even-only decoder.
        .text
        .globl main
        .globl d6v037_encode_literals
        .globl d6v037_encode_cursor
main:
        movei   1,source
        movei   2,0200
        movei   3,encoded
        movei   4,0300
        pushj   17,d6v037_encode_literals
        jumpl   1,error_encode
        ; Compare full encoded output from both implementations.
        movem   1,length_a
        movei   1,source
        movei   2,0200
        movei   3,encoded_b
        movei   4,0300
        pushj   17,d6v037_encode_cursor
        jumpl   1,error_encode
        came    1,length_a
        jrst    error_data
        movei   5,0
compare_stream:
        camge   5,length_a
        jrst    compare_word
        jrst    compare_done
compare_word:
        move    6,encoded(5)
        came    6,encoded_b(5)
        jrst    error_data
        aoja    5,compare_stream
compare_done:
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
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .word 0123456701234
        .bss
encoded: .block 0300
encoded_b: .block 0300
length_a: .block 1
decoded: .block 0200
        .globl __test_exit
__test_exit: .block 1
