/* Native PDP-6 inline token decoder: odd distance, split input, zero run. */
.text
.globl main
main:
        movei 1,d6i65_image_start
        hrl 1,1
        hrri 1,000060
        blt 1,000060+(d6i65_image_end-d6i65_image_start)-1
        movei 3,stream
        movei 4,2
        movei 12,result
        movei 13,3
        move 14,12
        setz 10,
        setz 11,
        pushj 17,000060
        caie 0,1
        jrst fail
        movei 4,1
        pushj 17,000060
        jumpn 0,fail
        movei 5,0
check:
        move 6,result(5)
        came 6,expected(5)
        jrst fail
        aoj 5,
        caige 5,3
        jrst check
        setz 1,
        popj 17,
fail:
        movei 1,1
        popj 17,
.data
/* Second token is an odd-halfword distance-one length-two match. */
stream:
        .word 0200000000000
        .word 012345023456
        .word 0402001
expected:
        .word 012345023456
        .word 023456023456
        .word 023456023456
.bss
result: .block 3
.globl __test_exit
__test_exit: .block 1
