/* Exact capacity and 30-token group boundary for the staged codec. */
        .text
        .globl main
        .globl d6codec_kcore_encode_v055
        .globl d6codec_kcore_decode_v055
        .globl d6codec_v053_max_encoded_words
main:
        ; Verify the allocation-free maximum-output formula.
        setz    1,
        pushj   17,d6codec_v053_max_encoded_words
        jumpn   1,fail1
        movei   1,1
        pushj   17,d6codec_v053_max_encoded_words
        caie    1,2
        jrst    fail1
        movei   1,036
        pushj   17,d6codec_v053_max_encoded_words
        caie    1,037
        jrst    fail1
        movei   1,037
        pushj   17,d6codec_v053_max_encoded_words
        caie    1,041
        jrst    fail1
        ; Exact last representable upper bound: 0757367 + 020411.
        move    1,[0757367]
        pushj   17,d6codec_v053_max_encoded_words
        came    1,[01000000]
        jrst    fail1
        ; One additional source word would exceed the address space.
        move    1,[0757370]
        pushj   17,d6codec_v053_max_encoded_words
        camn    1,[-1]
        jrst    check_high_count
        jrst    fail1
check_high_count:
        move    1,[01000000]
        pushj   17,d6codec_v053_max_encoded_words
        camn    1,[-1]
        jrst    check_negative_count
        jrst    fail1
check_negative_count:
        seto    1,
        pushj   17,d6codec_v053_max_encoded_words
        camn    1,[-1]
        jrst    check_all_max
        jrst    fail1
check_all_max:
        movei   1,0777777
        pushj   17,d6codec_v053_max_encoded_words
        camn    1,[-1]
        jrst    capacity_tests
        jrst    fail1
capacity_tests:
        ; Thirty distinct literals: one header plus 30 words.
        move    0,[012345670123]
        movem   0,encoded+036
        movei   1,source
        movei   2,036
        movei   3,encoded
        movei   4,036
        pushj   17,d6codec_kcore_encode_v055
        camn    1,[-1]
        jrst    check_guard30
        jrst    fail1
check_guard30:
        move    0,encoded+036
        came    0,[012345670123]
        jrst    fail2
        movei   1,source
        movei   2,036
        movei   3,encoded
        movei   4,037
        pushj   17,d6codec_kcore_encode_v055
        caie    1,037
        jrst    fail3
        movei   1,encoded
        movei   2,037
        movei   3,decoded
        movei   4,036
        pushj   17,d6codec_kcore_decode_v055
        jumpn   1,fail4
        movei   5,0
check30:
        move    6,source(5)
        came    6,decoded(5)
        jrst    fail4
        aoj     5,
        caige   5,036
        jrst    check30
        ; Thirty-one literals require two group headers: 33 words.
        move    0,[012345670123]
        movem   0,encoded+040
        movei   1,source
        movei   2,037
        movei   3,encoded
        movei   4,040
        pushj   17,d6codec_kcore_encode_v055
        camn    1,[-1]
        jrst    check_guard31
        jrst    fail5
check_guard31:
        move    0,encoded+040
        came    0,[012345670123]
        jrst    fail6
        movei   1,source
        movei   2,037
        movei   3,encoded
        movei   4,041
        pushj   17,d6codec_kcore_encode_v055
        caie    1,041
        jrst    fail7
        movei   1,encoded
        movei   2,041
        movei   3,decoded
        movei   4,037
        pushj   17,d6codec_kcore_decode_v055
        jumpn   1,fail8
        movei   5,0
check31:
        move    6,source(5)
        came    6,decoded(5)
        jrst    fail8
        aoj     5,
        caige   5,037
        jrst    check31
        ; A single zero word also needs two output words:
        ; one header plus a packed zero-run descriptor.
        movei   1,zero_source
        movei   2,1
        movei   3,encoded
        movei   4,1
        pushj   17,d6codec_kcore_encode_v055
        camn    1,[-1]
        jrst    zero_exact
        jrst    fail9
zero_exact:
        movei   1,zero_source
        movei   2,1
        movei   3,encoded
        movei   4,2
        pushj   17,d6codec_kcore_encode_v055
        caie    1,2
        jrst    fail10
        movei   1,encoded
        movei   2,2
        movei   3,decoded
        movei   4,1
        pushj   17,d6codec_kcore_decode_v055
        jumpn   1,fail10
        skipn   decoded
        jrst    success
        jrst    fail10
success:
        setz    1,
        popj    17,
fail1:  movei 1,1
        popj 17,
fail2:  movei 1,2
        popj 17,
fail3:  movei 1,3
        popj 17,
fail4:  movei 1,4
        popj 17,
fail5:  movei 1,5
        popj 17,
fail6:  movei 1,6
        popj 17,
fail7:  movei 1,7
        popj 17,
fail8:  movei 1,010
        popj 17,
fail9:  movei 1,011
        popj 17,
fail10: movei 1,012
        popj 17,
        .data
source:
        .word 1
        .word 2
        .word 3
        .word 4
        .word 5
        .word 6
        .word 7
        .word 10
        .word 11
        .word 12
        .word 13
        .word 14
        .word 15
        .word 16
        .word 17
        .word 20
        .word 21
        .word 22
        .word 23
        .word 24
        .word 25
        .word 26
        .word 27
        .word 30
        .word 31
        .word 32
        .word 33
        .word 34
        .word 35
        .word 36
        .word 37
zero_source:
        .word 0
        .bss
encoded: .block 043
decoded: .block 037
        .globl __test_exit
__test_exit: .block 1
