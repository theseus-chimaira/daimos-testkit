        .text
        .globl  _start
_start:
        move    17,[0777700,,stack-1]
        pushj   17,install_d6lz_decoder
        pushj   17,daimos_swap_pure_text_pdp6_test
        movem   1,daimos_swap_pure_text_pdp6_result
        halt    .

        .bss
stack:  .block  0400
