/* Staged D6 codec decoder rejection and non-overlap regression. */
        .text
        .globl main
        .globl d6codec_kcore_decode_v055
main:
        ; Control flags outside the declared single token are invalid.
        movei   1,bad_flags
        movei   2,2
        movei   3,outbuf
        movei   4,1
        pushj   17,d6codec_kcore_decode_v055
        camn    1,[-1]
        jrst    check_descriptor
        jrst    fail1
check_descriptor:
        ; The unused low descriptor half must be zero.
        movei   1,bad_descriptor
        movei   2,2
        movei   3,outbuf
        movei   4,1
        pushj   17,d6codec_kcore_decode_v055
        camn    1,[-1]
        jrst    check_wrap
        jrst    fail2
check_wrap:
        ; Source lies at the final 18-bit address: length two wraps.
        move    0,[012345670123]
        movem   0,outbuf
        movei   1,0777777
        movei   2,2
        movei   3,outbuf
        movei   4,1
        pushj   17,d6codec_kcore_decode_v055
        camn    1,[-1]
        jrst    check_wrap_guard
        jrst    fail3
check_wrap_guard:
        move    0,outbuf
        came    0,[012345670123]
        jrst    fail3
        ; The output endpoint must also remain in physical memory.
        movei   1,valid_literal
        movei   2,2
        movei   3,0777777
        movei   4,2
        pushj   17,d6codec_kcore_decode_v055
        camn    1,[-1]
        jrst    check_high_pointer
        jrst    fail3
check_high_pointer:
        ; An input pointer with non-address high bits is invalid.
        move    1,[01000000]
        movei   2,2
        movei   3,outbuf
        movei   4,1
        pushj   17,d6codec_kcore_decode_v055
        camn    1,[-1]
        jrst    check_overlap
        jrst    fail3
check_overlap:
        ; In-place decoding would overwrite the source literal.
        movei   1,valid_literal
        movei   2,2
        movei   3,valid_literal+1
        movei   4,1
        pushj   17,d6codec_kcore_decode_v055
        camn    1,[-1]
        jrst    check_valid
        jrst    fail4
check_valid:
        ; Non-overlapping, canonical input remains accepted.
        movei   1,valid_literal
        movei   2,2
        movei   3,outbuf
        movei   4,1
        pushj   17,d6codec_kcore_decode_v055
        jumpn   1,fail5
        move    0,outbuf
        came    0,[052]
        jrst    fail6
        move    0,valid_literal+1
        came    0,[052]
        jrst    fail7
        setz    1,
        popj    17,
fail5:
        movei   1,5
        popj    17,
fail6:
        movei   1,6
        popj    17,
fail7:
        movei   1,7
        popj    17,
fail4:
        movei   1,4
        popj    17,
fail3:
        movei   1,3
        popj    17,
fail2:
        movei   1,2
        popj    17,
fail1:
        movei   1,1
        popj    17,
        .data
bad_flags:
        .word   010000000001
        .word   052
bad_descriptor:
        .word   014000000000
        .word   0201000000001
valid_literal:
        .word   010000000000
        .word   052
        .bss
outbuf: .block 1
        .globl __test_exit
__test_exit: .block 1
