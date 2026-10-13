        .text
        .globl main
        .globl d6v019_decode
main:
        movei 1,stream
        movei 2,3
        movei 3,output
        movei 4,4
        pushj 17,d6v019_decode
        jumpn 1,failed
        movei 5,0
check:
        move 6,output(5)
        came 6,expected(5)
        jrst failed
        aoj 5,
        caige 5,4
        jrst check
        setz 1,
        popj 17,
failed: movei 1,1
        popj 17,
        .data
; Two tokens: literal followed by kind2 halfword match,
; 3 words long with two-halfword (one-word) backward distance.
stream:
        .word 022000000000
        .word 0403002,,0
        .word 012345670123
expected:
        .word 012345670123
        .word 012345670123
        .word 012345670123
        .word 012345670123
        .bss
output: .block 4
        .globl __test_exit
__test_exit: .block 1
