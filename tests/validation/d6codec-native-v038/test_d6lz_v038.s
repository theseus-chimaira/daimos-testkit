; Standalone target test: assembler encoder -> native even-only decoder.
        .text
        .globl main
        .globl d6v038_encode_literals
        .globl d6v038_encode_cursor
main:
        movei   1,source
        movei   2,0200
        movei   3,encoded
        movei   4,0300
        pushj   17,d6v038_encode_literals
        jumpl   1,error_encode
        ; Compare full encoded output from both implementations.
        movem   1,length_a
        movei   1,source
        movei   2,0200
        movei   3,encoded_b
        movei   4,0300
        pushj   17,d6v038_encode_cursor
        jumpl   1,error_encode
        came    1,length_a
        jrst    error_data
        movei   5,0
compare_stream:
        camge   5,length_a
        jrst    compare_word
        jrst    compare_done
compare_word:
        move    6,encoded(5)
        came    6,encoded_b(5)
        jrst    error_data
        aoja    5,compare_stream
compare_done:
        setz    1,
        popj    17,
error_encode: movei 1,1
        popj 17,
error_decode: movei 1,2
        popj 17,
error_data: movei 1,3
        popj 17,
        .data
source:
        .word 0200140000002
        .word 0200100000001
        .word 0201040000021
        .word 077001000000
        .word 0263740000000
        .word 0200200000003
        .word 0200140000002
        .word 0200100000001
        .word 0201040000040
        .word 077001000000
        .word 0263740000000
        .word 0200200000003
        .word 0200140000002
        .word 0200100000001
        .word 0201040000045
        .word 077001000000
        .word 0263740000000
        .word 0200200000003
        .word 0200140000002
        .word 0200100000001
        .word 0201040000041
        .word 077001000000
        .word 0263740000000
        .word 0200200000003
        .word 0200140000002
        .word 0200100000001
        .word 0201040000042
        .word 077001000000
        .word 0263740000000
        .word 0201100000777
        .word 051001000000
        .word 0263740000000
        .word 0261740000010
        .word 0200400000001
        .word 0261740000011
        .word 0200440000002
        .word 0261740000012
        .word 0200500000003
        .word 0270740001734
        .word 0335040000010
        .word 0254000000274
        .word 0336100000011
        .word 0336140000012
        .word 0254000000276
        .word 0474040000000
        .word 0254000000364
        .word 0332040000012
        .word 0254000000302
        .word 0414040000001
        .word 0254000000364
        .word 0200040000011
        .word 0200100000001
        .word 0200140000012
        .word 0200040000010
        .word 056001000000
        .word 0202057000000
        .word 0200140000001
        .word 0312140000012
        .word 0254000000315
        .word 0400040000000
        .word 0254000000364
        .word 0337157000000
        .word 0254000000324
        .word 0641140400000
        .word 0200040000012
        .word 0641040400000
        .word 0317140000001
        .word 0254000000326
        .word 0474040000000
        .word 0254000000364
        .word 0200117000000
        .word 0202117777777
        .word 0200117777777
        .word 0641100400000
        .word 0200040000012
        .word 0641040400000
        .word 0311100000001
        .word 0254000000363
        .word 0200040000012
        .word 0274057777777
        .word 0200100000011
        .word 0270117777777
        .word 0200140000001
        .word 0200040000010
        .word 056001000000
        .word 0202057000000
        .word 0337200000001
        .word 0254000000356
        .word 0641200400000
        .word 0200100000012
        .word 0274117777777
        .word 0641100400000
        .word 0317200000002
        .word 0254000000360
        .word 0474040000000
        .word 0254000000364
        .word 0200157000000
        .word 0273157777777
        .word 0254000000330
        .word 0400040000000
        .word 0200417777774
        .word 0200457777775
        .word 0200517777776
        .word 0274740001735
        .word 0263740000000
        .word 0261740000016
        .word 0261740000010
        .word 0200400000001
        .word 0270740001734
        .word 0331100003204
        .word 0254000000401
        .word 0201040000001
        .word 0254000000446
        .word 0332100003205
        .word 0254000000407
        .word 0200040000010
        .word 0326040000407
        .word 0414040000001
        .word 0254000000446
        .word 0200100003205
        .word 0661100010000
        .word 0202100003206
        .word 0200140003205
        .word 0271140000005
        .word 0331200000003
        .word 0634140000003
        .word 0201140000001
        .word 0235140000006
        .bss
encoded: .block 0300
encoded_b: .block 0300
length_a: .block 1
decoded: .block 0200
        .globl __test_exit
__test_exit: .block 1
