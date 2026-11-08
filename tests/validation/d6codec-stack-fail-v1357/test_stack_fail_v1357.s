/* Native PDP-6 staged codec failures through the register-saving ABI. */
        .text
        .globl main
        .globl d6codec_kcore_encode_v055
        .globl d6codec_kcore_decode_v055
main:
        ; Reject malformed stream after reading a control word.
        movei 1,invalid_group
        movei 2,1
        movei 3,output
        movei 4,1
        pushj 17,d6codec_kcore_decode_v055
        camn 1,[-1]
        jrst check_input_geometry
        jrst fail1
check_input_geometry:
        ; Reject wrap before touching the unavailable input address.
        movei 1,0777777
        movei 2,2
        movei 3,output
        movei 4,1
        pushj 17,d6codec_kcore_decode_v055
        camn 1,[-1]
        jrst check_encode_short
        jrst fail2
check_encode_short:
        ; Capacity one allows a header, but not a first literal.
        movei 1,source
        movei 2,3
        movei 3,output
        movei 4,1
        pushj 17,d6codec_kcore_encode_v055
        camn 1,[-1]
        jrst check_encode_zero
        jrst fail3
check_encode_zero:
        ; A zero-run descriptor requires more than its group header.
        movei 1,zero_source
        movei 2,2
        movei 3,output
        movei 4,1
        pushj 17,d6codec_kcore_encode_v055
        camn 1,[-1]
        jrst check_encode_match
        jrst fail4
check_encode_match:
        ; The repeated words exercise the encoder search subroutine.
        ; Capacity two forces a refusal after entering that path.
        movei 1,repeat_source
        movei 2,4
        movei 3,output
        movei 4,2
        pushj 17,d6codec_kcore_encode_v055
        camn 1,[-1]
        jrst success
        jrst fail5
success:
        setz 1,
        popj 17,
fail1:   movei 1,1
        popj 17,
fail2:   movei 1,2
        popj 17,
fail3:   movei 1,3
        popj 17,
fail4:   movei 1,4
        popj 17,
fail5:   movei 1,5
        popj 17,
        .data
invalid_group:
        .word 010000000000
source:
        .word 052
        .word 053
        .word 054
zero_source:
        .word 0
        .word 0
repeat_source:
        .word 012345
        .word 012345
        .word 012345
        .word 012345
        .bss
output:  .block 010
        .globl __test_exit
__test_exit: .block 1
