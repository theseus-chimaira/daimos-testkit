; Execute the production CTY packed FIFO leaves on PDP-6.
; Includes embedded NUL, 5-character word crossing, full refusal, and reuse.
        .text
        .globl main
main:
        movei 5,inputs
        movei 6,012                   ; ten characters
cty_test_fill:
        move 1,(5)
        pushj 17,cty_rx_put
        jumpn 1,cty_test_fail
        aoj 5,
        sojg 6,cty_test_fill
        move 2,cty_rx_count
        caie 2,012
        jrst cty_test_fail
        move 3,cty_rx_words
        move 4,cty_rx_words+1
        movei 1,077
        pushj 17,cty_rx_put           ; the full queue must not be changed
        camn 1,[-1]
        jrst cty_test_full
        jrst cty_test_fail
cty_test_full:
        camn 3,cty_rx_words
        jrst cty_test_full2
        jrst cty_test_fail
cty_test_full2:
        camn 4,cty_rx_words+1
        jrst cty_test_check
        jrst cty_test_fail
cty_test_check:
        movei 5,inputs
        movei 6,012
cty_test_drain:
        pushj 17,cty_rx_get
        came 1,(5)
        jrst cty_test_fail
        aoj 5,
        sojg 6,cty_test_drain
        skipn cty_rx_count
        jrst cty_test_empty
        jrst cty_test_fail
cty_test_empty:
        pushj 17,cty_rx_get
        camn 1,[-1]
        jrst cty_test_reuse
        jrst cty_test_fail
cty_test_reuse:
        movei 1,0177
        pushj 17,cty_rx_put
        jumpn 1,cty_test_fail
        pushj 17,cty_rx_get
        caie 1,0177
        jrst cty_test_fail
        skipn cty_rx_words
        jrst cty_test_clear
        jrst cty_test_fail
cty_test_clear:
        skipn cty_rx_words+1
        jrst cty_test_pass
        jrst cty_test_fail
cty_test_pass:
        setz 1,
        popj 17,
cty_test_fail:
        movei 1,1
        popj 17,

        .data
inputs:
        .word 0
        .word 0122
        .word 0117
        .word 0117
        .word 0124
        .word 015
        .word 040
        .word 0101
        .word 0102
        .word 0177

        .bss
        .globl cty_rx_words
cty_rx_words: .block 2
        .globl cty_rx_count
cty_rx_count: .block 1
        .globl __test_exit
__test_exit: .block 1
