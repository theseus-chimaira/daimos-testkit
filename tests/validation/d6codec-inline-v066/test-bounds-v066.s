/* Reject 18-bit source/output wrap before dereferencing either buffer. */
.text
.globl main
main:
        movei 1,d6i66_image_start
        hrl 1,1
        hrri 1,000060
        blt 1,000060+(d6i66_image_end-d6i66_image_start)-1
        movei 3,stream
        movei 4,3
        movei 12,0777777
        movei 13,3
        move 14,12
        setz 10,
        setz 11,
        pushj 17,000060
        move 1,0
        aoj 1,
        jumpn 1,fail1
        movei 3,0777777
        movei 4,3
        movei 12,output
        movei 13,3
        move 14,12
        setz 10,
        setz 11,
        pushj 17,000060
        move 1,0
        aoj 1,
        jumpn 1,fail2
        movei 3,stream
        movei 4,3
        movei 12,output
        movei 13,3
        move 14,12
        aoj 14,                     ; output cursor below base
        setz 10,
        setz 11,
        pushj 17,000060
        move 1,0
        aoj 1,
        jumpn 1,fail
        setz 1,
        popj 17,
fail1:
        movei 1,1
        popj 17,
fail2:
        movei 1,2
        popj 17,
fail:
        movei 1,3
        popj 17,
.data
stream:
        .word 022000000000
        .word 0402001000000
        .word 012345023456
.bss
output: .block 3
.globl __test_exit
__test_exit: .block 1
