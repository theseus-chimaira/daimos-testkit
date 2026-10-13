/* Native v073 KPACK adapter encode/decode on PDP-6. */
.text
.globl main
main:
        movei 1,d6i67_image_start
        hrl 1,1
        hrri 1,000060
        blt 1,000060+(d6i67_image_end-d6i67_image_start)-1
        movei 10,012345
        movei 11,023456
        movei 12,034567
        movei 13,045670
        movei 14,056701
        movei 15,067012
        movei 16,070123
        movei 1,source
        movei 2,6
        movei 3,encoded
        movei 4,32
        pushj 17,d6codec_kpack_inline_encode_v073
        jumple 1,fail
        caie 10,012345
        jrst fail
        caie 11,023456
        jrst fail
        caie 16,070123
        jrst fail
        move 2,1
        movei 1,encoded
        movei 3,decoded
        movei 4,6
        pushj 17,d6codec_kpack_inline_decode_v073
        caie 1,6
        jrst fail
        caie 10,012345
        jrst fail
        caie 16,070123
        jrst fail
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
fail:
        movei 1,1
        popj 17,
.data
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
