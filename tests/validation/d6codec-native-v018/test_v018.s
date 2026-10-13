        .text
        .globl main
        .globl d6v018_decode
main:
        ; Group 1: literal, copy(len3,dist1), zero(len3).
        ; Group 2: literal, copy(len2,dist1).
        movei 1,stream
        movei 2,6
        movei 3,output
        movei 4,012
        pushj 17,d6v018_decode
        jumpn 1,failed_decode
        movei 5,0
check:
        move 6,output(5)
        came 6,expected(5)
        jrst failed_data
        aoj 5,
        caige 5,012
        jrst check
        ; Zero-length matches are malformed.
        movei 1,bad_stream
        movei 2,3
        movei 3,scratch
        movei 4,2
        pushj 17,d6v018_decode
        jumpe 1,failed
        ; Truncated token group must be rejected.
        movei 1,stream
        movei 2,2
        movei 3,scratch
        movei 4,7
        pushj 17,d6v018_decode
        jumpe 1,failed
        setz 1,
        popj 17,
failed_decode: movei 1,2
        popj 17,
failed_data: movei 1,3
        popj 17,
failed: movei 1,1
        popj 17,
        .data
stream:
        .word 033000000000
        .word 03001,,0203000
        .word 0123456701
        .word 022000000000
        .word 02001,,0
        .word 0123456701
expected:
        .word 0123456701
        .word 0123456701
        .word 0123456701
        .word 0123456701
        .word 0
        .word 0
        .word 0
        .word 0123456701
        .word 0123456701
        .word 0123456701
bad_stream:
        .word 022000000000
        .word 0,,0
        .word 0123456701
        .bss
output: .block 012
scratch: .block 010
        .globl __test_exit
__test_exit: .block 1
