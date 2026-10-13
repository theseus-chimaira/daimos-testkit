/* Fixed 000060 new codec must reject malformed groups. */
.text
.globl main
main:
        movei 1,d6codec_image_start
        hrl 1,1
        hrri 1,000060
        blt 1,000060+(d6codec_image_end-d6codec_image_start)-1
        movei 3,bad_zero_count
        movei 4,3
        movei 12,output
        movei 13,3
        move 14,12
        setz 10,
        setz 11,
        pushj 17,000060
        move 1,0
        aoj 1,
        jumpn 1,fail
        movei 3,bad_count31
        movei 4,3
        movei 12,output
        movei 13,3
        move 14,12
        setz 10,
        setz 11,
        pushj 17,000060
        move 1,0
        aoj 1,
        jumpn 1,fail
        movei 3,bad_reserved_low
        movei 4,3
        movei 12,output
        movei 13,3
        move 14,12
        setz 10,
        setz 11,
        pushj 17,000060
        move 1,0
        aoj 1,
        jumpn 1,fail
        movei 3,bad_unused_flag
        movei 4,3
        movei 12,output
        movei 13,3
        move 14,12
        setz 10,
        setz 11,
        pushj 17,000060
        move 1,0
        aoj 1,
        jumpn 1,fail
        movei 3,bad_descriptor_padding
        movei 4,3
        movei 12,output
        movei 13,3
        move 14,12
        setz 10,
        setz 11,
        pushj 17,000060
        move 1,0
        aoj 1,
        jumpn 1,fail
        movei 3,bad_zero_length
        movei 4,3
        movei 12,output
        movei 13,3
        move 14,12
        setz 10,
        setz 11,
        pushj 17,000060
        move 1,0
        aoj 1,
        jumpn 1,fail
        movei 3,bad_invalid_kind
        movei 4,3
        movei 12,output
        movei 13,3
        move 14,12
        setz 10,
        setz 11,
        pushj 17,000060
        move 1,0
        aoj 1,
        jumpn 1,fail
        setz 1,
        popj 17,
fail:
        movei 1,1
        popj 17,
.data
bad_zero_count:
        .word 000000000000
        .word 000000000000
        .word 000000000000
bad_count31:
        .word 0370000000000
        .word 000000000000
        .word 000000000000
bad_reserved_low:
        .word 022000000001
        .word 0402001000000
        .word 012345023456
bad_unused_flag:
        .word 023000000000
        .word 0402001000000
        .word 012345023456
bad_descriptor_padding:
        .word 022000000000
        .word 0402001000001
        .word 012345023456
bad_zero_length:
        .word 022000000000
        .word 0400001000000
        .word 012345023456
bad_invalid_kind:
        .word 022000000000
        .word 0602001000000
        .word 012345023456
.bss
output: .block 3
.globl __test_exit
__test_exit: .block 1
