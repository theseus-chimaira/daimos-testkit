/* Native v078 KPACK adapter encode/decode on PDP-6. */
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
        pushj 17,d6codec_kpack_inline_size_v078
        jumple 1,fail_measure
        movem 1,expected_size_v078      ; encoder may clobber AC7
        movei 1,source
        movei 2,6
        movei 3,encoded
        movei 4,32
        pushj 17,d6codec_kpack_inline_encode_v078
        jumple 1,fail_encode
        came 1,expected_size_v078
        jrst fail_size
        jrst size_good
size_good:
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
        pushj 17,d6codec_kpack_inline_decode_v078
        caie 1,6
        jrst fail_decode
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
        ; Long zero run crosses the 127-word match-length boundary.
        ; One control plus two zero descriptors must take three words.
        movei 1,zeros128
        movei 2,0200
        pushj 17,d6codec_kpack_inline_size_v078
        caie 1,3
        jrst fail_measure
        movei 1,zeros128
        movei 2,0200
        movei 3,encoded128
        movei 4,040
        pushj 17,d6codec_kpack_inline_encode_v078
        caie 1,3
        jrst fail_encode
        movei 1,encoded128
        movei 2,3
        movei 3,decoded128
        movei 4,0200
        pushj 17,d6codec_kpack_inline_decode_v078
        caie 1,0200
        jrst fail_decode
        movei 5,0
verify128:
        skipn decoded128(5)
        jrst zero_ok
        jrst fail
zero_ok:
        aoj 5,
        caige 5,0200
        jrst verify128
        setz 1,
        popj 17,
fail_measure:
        movei 1,2
        popj 17,
fail_encode:
        movei 1,3
        popj 17,
fail_size:
        move 1,1
        addi 1,0100
        popj 17,
fail_decode:
        movei 1,5
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
expected_size_v078: .block 1
zeros128: .block 0200
encoded128: .block 040
decoded128: .block 0200
.globl __test_exit
__test_exit: .block 1
