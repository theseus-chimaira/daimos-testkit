; Fill three consecutive 36-bit words with exact 9-bit ASCII characters.
; Byte pointer in AC1; HRRZ retrieves its word address.  This independent
; assembly oracle checks compiled char[] reads without using GCC char stores.
        .text
        .globl  pdp10_fill_char_line_v45
pdp10_fill_char_line_v45:
        hrrz    1,1
        move    2,[043043040100]        ; ## @
        movem   2,(1)
        move    2,[077117120105]        ; ?OPE
        movem   2,1(1)
        move    2,[0122101116104]       ; RAND
        movem   2,2(1)
        move    2,[0123000000000]       ; S\0\0\0
        movem   2,3(1)
        popj    17,

        .bss
        .globl  __test_exit
__test_exit:
        .block  1
