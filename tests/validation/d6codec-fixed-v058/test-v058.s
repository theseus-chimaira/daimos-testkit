/* Native PDP-6 group-atomic streaming ABI tests, no extra buffers. */
.text
.globl main
main:
        movei 1,d6codec_image_start
        hrl 1,1
        hrri 1,000060
        blt 1,000060+(d6codec_image_end-d6codec_image_start)-1
        movei 15,012345
        movei 16,023456
        movei 3,stream1
        movei 4,2                  ; one group word still missing
        movei 12,output1
        movei 13,3
        move 14,12
        setz 10,
        setz 11,
        pushj 17,000060
        caie 0,1
        jrst fail
        caie 4,2
        jrst fail
        caie 13,3
        jrst fail
        caie 11,0
        jrst fail
        movei 4,3                  ; append missing literal in place
        pushj 17,000060
        jumpn 0,fail
        jumpn 13,fail
        jumpn 4,fail
        movei 5,0
check1:
        move 6,output1(5)
        came 6,expected1(5)
        jrst fail
        aoj 5,
        caige 5,3
        jrst check1
        movei 3,stream3
        movei 4,4
        movei 12,output3
        movei 13,4
        move 14,12
        setz 10,
        setz 11,
        pushj 17,000060
        jumpn 0,fail
        jumpn 13,fail
        jumpn 4,fail
        movei 5,0
check3:
        move 6,output3(5)
        came 6,expected3(5)
        jrst fail
        aoj 5,
        caige 5,4
        jrst check3
        movei 1,1
        movem 1,split_count
split_loop:
        movei 3,stream30
        move 4,split_count
        movei 12,output30
        movei 13,036
        move 14,12
        setz 10,
        setz 11,
        pushj 17,000060
        caie 0,1
        jrst fail
        move 1,split_count
        came 4,1
        jrst fail
        caie 13,036
        jrst fail
        movei 4,037
        pushj 17,000060
        jumpn 0,fail
        jumpn 13,fail
        jumpn 4,fail
        movei 5,0
split_check:
        move 6,output30(5)
        came 6,expected30(5)
        jrst fail
        aoj 5,
        caige 5,036
        jrst split_check
        aos 1,split_count
        caige 1,037
        jrst split_loop
        caie 15,012345
        jrst fail
        caie 16,023456
        jrst fail
        setz 1,
        popj 17,
fail:
        movei 1,1
        popj 17,
.data
stream1:
        .word 022000000000
        .word 0402001000000
        .word 012345023456
expected1:
        .word 012345023456
        .word 023456023456
        .word 023456023456
stream3:
        .word 031000000000
        .word 0402003000000
        .word 011111022222
        .word 033333044444
expected3:
        .word 011111022222
        .word 033333044444
        .word 022222033333
        .word 044444022222
/* Maximum-sized all-literal group: 30 words plus one control word. */
stream30:
        .word 0360000000000
        .word 000000000001
        .word 000000000002
        .word 000000000003
        .word 000000000004
        .word 000000000005
        .word 000000000006
        .word 000000000007
        .word 000000000010
        .word 000000000011
        .word 000000000012
        .word 000000000013
        .word 000000000014
        .word 000000000015
        .word 000000000016
        .word 000000000017
        .word 000000000020
        .word 000000000021
        .word 000000000022
        .word 000000000023
        .word 000000000024
        .word 000000000025
        .word 000000000026
        .word 000000000027
        .word 000000000030
        .word 000000000031
        .word 000000000032
        .word 000000000033
        .word 000000000034
        .word 000000000035
        .word 000000000036
expected30:
        .word 000000000001
        .word 000000000002
        .word 000000000003
        .word 000000000004
        .word 000000000005
        .word 000000000006
        .word 000000000007
        .word 000000000010
        .word 000000000011
        .word 000000000012
        .word 000000000013
        .word 000000000014
        .word 000000000015
        .word 000000000016
        .word 000000000017
        .word 000000000020
        .word 000000000021
        .word 000000000022
        .word 000000000023
        .word 000000000024
        .word 000000000025
        .word 000000000026
        .word 000000000027
        .word 000000000030
        .word 000000000031
        .word 000000000032
        .word 000000000033
        .word 000000000034
        .word 000000000035
        .word 000000000036
.bss
split_count: .block 1
output30: .block 036
output1: .block 3
output3: .block 4
.globl __test_exit
__test_exit: .block 1
