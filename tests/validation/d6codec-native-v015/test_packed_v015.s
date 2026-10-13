        .text
        .globl main
        .globl d6v015_decode
main:
        movei 1,compressed
        movei 2,3
        movei 3,decoded
        movei 4,7
        pushj 17,d6v015_decode
        jumpn 1,bad
        movei 5,0
check:
        move 6,decoded(5)
        came 6,expected(5)
        jrst bad
        aoj 5,
        caige 5,7
        jrst check
        setz 1,
        popj 17,
bad:    movei 1,1
        popj 17,
        .data
; 3 tokens: literal, word-match (len 3 distance 1), zero-run len 3.
; Control count=3, match flags at bit28 and bit27.
compressed:
        .word 033000000000
; Packed descriptors: kind 0,len3,dist1 = 03001 octal;
; kind 1,len3,dist0 = 0203000 octal.
        .word 03001,,0203000
        .word 0123456701
expected:
        .word 0123456701
        .word 0123456701
        .word 0123456701
        .word 0123456701
        .word 0
        .word 0
        .word 0
        .bss
decoded: .block 7
        .globl __test_exit
__test_exit: .block 1
