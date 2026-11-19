; Native PDP-6 source-authentic physical Type-551 DTC0 block-read probe.
; No filesystem stubs, no simulated completion, no production patch.
; The runner varies only the FIRST_BLOCK constant between a near read
; and a high-to-low reversal requiring the same target RBN block 4.
        .text
        .globl main
        .globl storage_pi_handler
        .globl storage_dct_handler
        .globl storage_pi_tape_jump
        .globl storage_dct_tape_jump
        .globl tape_pi_handler
        .globl tape_dct_handler
        .globl dtc_read_block

        .set FIRST_BLOCK,0341
main:
        ; The same resident Type-136 routing as the original DTC native test.
        movei 1,tape_pi_handler
        hrrm 1,storage_pi_tape_jump
        movei 1,tape_dct_handler
        hrrm 1,storage_dct_tape_jump
        move 1,[jsr dtc_v1619_pi3]
        movem 1,000047
        move 1,[jsr dtc_v1619_pi5]
        movem 1,000052
        setzm 000046
        cono 0004,010000
        movei 1,002224
        cono 0004,0(1)

        ; Read high block first, leaving the real tape far beyond block 4.
        ; The near-control variant substitutes FIRST_BLOCK=000004.
        setz 1,
        movei 2,FIRST_BLOCK
        movei 3,first_buf
        pushj 017,dtc_read_block
        jumpe 1,first_ok
        movei 1,1
        popj 017,
first_ok:
        ; Now locate and read physical block 4 using the original
        ; Type-551 RBN search/reversal/PI3/DCT transfer code.
        setz 1,
        movei 2,000004
        movei 3,last_buf
        pushj 017,dtc_read_block
        jumpe 1,second_ok
        movei 1,2
        popj 017,
second_ok:
        ; Successful read must have actually filled a nonzero block.
        movei 2,last_buf
        movei 3,0200
        setz 4,
scan_block:
        ior 4,(2)
        aoj 2,
        sojg 3,scan_block
        jumpn 4,read_ok
        movei 1,3
        popj 017,
read_ok:
        setz 1,
        popj 017,

; Real PDP-6 JSR/PI3/PI5 tails, preserving interrupted AC1..AC3.
dtc_v1619_pi3:
        .word 0
        movem 1,pi3_ac1
        movem 2,pi3_ac2
        movem 3,pi3_ac3
        pushj 017,storage_dct_handler
        move 1,pi3_ac1
        move 2,pi3_ac2
        move 3,pi3_ac3
        jrst 010,@dtc_v1619_pi3
dtc_v1619_pi5:
        .word 0
        movem 1,pi5_ac1
        movem 2,pi5_ac2
        movem 3,pi5_ac3
        pushj 017,storage_pi_handler
        move 1,pi5_ac1
        move 2,pi5_ac2
        move 3,pi5_ac3
        jrst 010,@dtc_v1619_pi5

        .bss
pi3_ac1: .block 1
pi3_ac2: .block 1
pi3_ac3: .block 1
pi5_ac1: .block 1
pi5_ac2: .block 1
pi5_ac3: .block 1
first_buf: .block 0200
last_buf: .block 0200
        .globl __test_exit
__test_exit: .block 1
