/* Native inline encoder -> fixed decoder roundtrip, with zero run. */
.text
.globl main
main:
        movei 1,source
        movei 2,6
        movei 3,encoded
        movei 4,32
        pushj 17,d6codec_inline_encode_v071
        jumple 1,fail_encode
        move 4,1
        move 6,encoded
        came 6,expected_control
        jrst fail_control
        movei 1,d6i67_image_start
        hrl 1,1
        hrri 1,000060
        blt 1,000060+(d6i67_image_end-d6i67_image_start)-1
        movei 3,encoded
        movei 12,decoded
        movei 13,6
        move 14,12
        setz 10,
        setz 11,
        pushj 17,000060
        jumpn 0,fail_decode
        movei 5,0
compare:
        move 6,source(5)
        came 6,decoded(5)
        jrst fail
        aoj 5,
        caige 5,6
        jrst compare
        setz 1,
        popj 17,
fail_encode:
        movei 1,2
        popj 17,
fail_control:
        movei 1,4
        popj 17,
fail_decode:
        movei 1,3
        popj 17,
fail:
        movei 1,1
        popj 17,
.data
expected_control: .word 0200000000000
source:
        .word 012345023456
        .word 0
        .word 0
        .word 0
        .word 012345023456
        .word 012345023456
.bss
encoded: .block 32
decoded: .block 6
.globl __test_exit
__test_exit: .block 1
