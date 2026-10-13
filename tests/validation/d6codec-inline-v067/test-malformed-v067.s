/* Reject malformed inline descriptors on native PDP-6. */
.text
.globl main
main:
        movei 1,d6i67_image_start
        hrl 1,1
        hrri 1,000060
        blt 1,000060+(d6i67_image_end-d6i67_image_start)-1
        movei 3,case_zero_length
        movei 4,2
        movei 12,output
        movei 13,3
        move 14,12
        setz 10,
        setz 11,
        pushj 17,000060
        move 1,0
        aoj 1,
        jumpn 1,fail
        movei 3,case_kind_three
        movei 4,2
        movei 12,output
        movei 13,3
        move 14,12
        setz 10,
        setz 11,
        pushj 17,000060
        move 1,0
        aoj 1,
        jumpn 1,fail
        movei 3,case_zero_word_distance
        movei 4,2
        movei 12,output
        movei 13,3
        move 14,12
        setz 10,
        setz 11,
        pushj 17,000060
        move 1,0
        aoj 1,
        jumpn 1,fail
        movei 3,case_zero_half_distance
        movei 4,2
        movei 12,output
        movei 13,3
        move 14,12
        setz 10,
        setz 11,
        pushj 17,000060
        move 1,0
        aoj 1,
        jumpn 1,fail
        movei 3,case_before_origin_word
        movei 4,2
        movei 12,output
        movei 13,3
        move 14,12
        setz 10,
        setz 11,
        pushj 17,000060
        move 1,0
        aoj 1,
        jumpn 1,fail
        movei 3,case_before_origin_half
        movei 4,2
        movei 12,output
        movei 13,3
        move 14,12
        setz 10,
        setz 11,
        pushj 17,000060
        move 1,0
        aoj 1,
        jumpn 1,fail
        movei 3,case_nonzero_zero_distance
        movei 4,2
        movei 12,output
        movei 13,3
        move 14,12
        setz 10,
        setz 11,
        pushj 17,000060
        move 1,0
        aoj 1,
        jumpn 1,fail
        movei 3,case_oversize_match
        movei 4,2
        movei 12,output
        movei 13,3
        move 14,12
        setz 10,
        setz 11,
        pushj 17,000060
        move 1,0
        aoj 1,
        jumpn 1,fail
        movei 3,case_high_descriptor_bits
        movei 4,2
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
case_zero_length:
        .word 0400000000000
        .word 01
case_kind_three:
        .word 0400000000000
        .word 0602001
case_zero_word_distance:
        .word 0400000000000
        .word 01000
case_zero_half_distance:
        .word 0400000000000
        .word 0402000
case_before_origin_word:
        .word 0400000000000
        .word 02001
case_before_origin_half:
        .word 0400000000000
        .word 0402001
case_nonzero_zero_distance:
        .word 0400000000000
        .word 0202001
case_oversize_match:
        .word 0400000000000
        .word 06001
case_high_descriptor_bits:
        .word 0400000000000
        .word 01000402001
.bss
output: .block 3
.globl __test_exit
__test_exit: .block 1
