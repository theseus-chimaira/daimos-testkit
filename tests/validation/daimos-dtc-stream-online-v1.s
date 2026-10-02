; Real Type-551 counted-transfer oracle for DAIMOS storage_io.s.
; Two adjacent 128-word blocks are written and read through the production
; dtc_write_block/dtc_read_block entries using their counted LH ABI.
        .text
        .globl main
        .globl storage_pi_handler
        .globl storage_dct_handler
        .globl storage_pi_tape_jump
        .globl storage_dct_tape_jump
        .globl tape_pi_handler
        .globl tape_dct_handler
        .globl dtc_read_block
        .globl dtc_write_block

main:
        ; Reproduce storage_minit(): bind the fixed router to this tape MRES.
        movei 1,tape_pi_handler
        hrrm 1,storage_pi_tape_jump
        movei 1,tape_dct_handler
        hrrm 1,storage_dct_tape_jump

        ; Install minimal PI3/PI5 JSR tails expected by storage_io.s.
        move 1,[jsr dtc_test_pi3]
        movem 1,000047
        move 1,[jsr dtc_test_pi5]
        movem 1,000052
        setzm 000046
        cono 0004,010000
        movei 1,002224              ; PI on + levels 3 (020) and 5 (004)
        cono 0004,0(1)

        ; Fill 256 words with a nonzero monotonic pattern.
        movei 1,write_buf
        movei 2,1
        movei 3,0400
fill_loop:
        movem 2,(1)
        aoj 1,
        aoj 2,
        sojg 3,fill_loop

        ; AC2 LH = (2-1)*0200, RH = first physical block 0200.
        setz 1,
        move 2,[000200,,000200]
        movei 3,write_buf
        pushj 017,dtc_write_block
        jumpe 1,write_ok
        movei 1,1
        popj 017,
write_ok:
        ; Read the same two-block ascending run.  This deliberately starts
        ; after the write left the transport coasting beyond the target, so
        ; SEARCH must reverse, reacquire the target, turn forward, then stream.
        setz 1,
        move 2,[000200,,000200]
        movei 3,read_buf
        pushj 017,dtc_read_block
        jumpe 1,read_ok
        movei 1,2
        popj 017,
read_ok:
        movei 1,write_buf
        movei 2,read_buf
        movei 3,0400
compare_loop:
        move 4,(1)
        came 4,(2)
        jrst compare_fail
        aoj 1,
        aoj 2,
        sojg 3,compare_loop
        setz 1,
        popj 017,
compare_fail:
        movei 1,3
        popj 017,

; PI wrappers preserve interrupted AC1..AC3, matching the production PI ABI.
dtc_test_pi3:
        .word 0
        movem 1,pi3_ac1
        movem 2,pi3_ac2
        movem 3,pi3_ac3
        pushj 017,storage_dct_handler
        move 1,pi3_ac1
        move 2,pi3_ac2
        move 3,pi3_ac3
        jrst 010,@dtc_test_pi3

dtc_test_pi5:
        .word 0
        movem 1,pi5_ac1
        movem 2,pi5_ac2
        movem 3,pi5_ac3
        pushj 017,storage_pi_handler
        move 1,pi5_ac1
        move 2,pi5_ac2
        move 3,pi5_ac3
        jrst 010,@dtc_test_pi5

        .bss
pi3_ac1:       .block 1
pi3_ac2:       .block 1
pi3_ac3:       .block 1
pi5_ac1:       .block 1
pi5_ac2:       .block 1
pi5_ac3:       .block 1
write_buf:     .block 0400
read_buf:      .block 0400
        .globl __test_exit
__test_exit:     .block 1
