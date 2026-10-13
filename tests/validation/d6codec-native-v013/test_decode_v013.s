        .text
        .globl main
        .globl d6lz_image_start
        .globl d6lz_image_end
        .globl d6v009_encode_literals
main:
        ; Install fixed low-core decoder without changing production image.
        movei   0,060
        hrli    0,d6lz_image_start
        blt     0,060+(d6lz_image_end-d6lz_image_start)-1
        ; Source has 8 zeros followed by 3 nonzero data words.
        movei   1,source+010
        movei   2,3
        movei   3,encoded
        movei   4,0100
        move    6,source+010
        jumpe   6,failed_source
        move    0,0(1)
        jumpe   0,failed_source
        pushj   17,d6v009_encode_literals
        jumpl   1,failed_encoder
        movem   1,encoded_len
        ; Decode direct from encoded contiguous memory.
        movei   3,encoded
        move    4,encoded_len
        movei   12,decoded
        movei   14,decoded
        movei   13,3
        setz    11,
        pushj   17,060
        jumpn   0,failed_decoder
        ; Check all 11 words and report success through crt.
        movei   5,0
check:
        move    6,source+010(5)
        came    6,decoded(5)
        jrst    failed_data
        aoj     5,
        caige   5,3
        jrst    check
        setz    1,
        popj    17,
failed_source:
        movei   1,4
        popj    17,
failed_encoder:
        movm    1,1
        popj    17,
failed_decoder:
        movei   1,2
        popj    17,
failed_data:
        movei   1,3
        popj    17,
        .data
source:
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0123456
        .word 0777777
        .word 0123456701

        .bss
encoded: .block 0100
decoded: .block 013
encoded_len: .block 1
        .globl __test_exit
__test_exit: .block 1
