; Type-516 online oracle using production DAIMOS record read/write paths.
        .text
        .globl main
        .globl storage_pi_handler
        .globl storage_dct_handler
        .globl storage_pi_tape_jump
        .globl storage_dct_tape_jump
        .globl tape_pi_handler
        .globl tape_dct_handler
        .globl mtc_service

main:
        ; Reproduce storage_minit(): bind the fixed router to this tape MRES.
        movei 1,tape_pi_handler
        hrrm 1,storage_pi_tape_jump
        movei 1,tape_dct_handler
        hrrm 1,storage_dct_tape_jump

        ; Install minimal PI3/PI5 JSR tails expected by storage_io.s.
        move 1,[jsr mtc_test_pi3]
        movem 1,000047
        move 1,[jsr mtc_test_pi5]
        movem 1,000052
        setzm 000046
        cono 0004,010000
        movei 1,002224
        cono 0004,0(1)

        ; STATUS is the readiness preflight for raw MTC operations.  MTC2 is
        ; enabled but deliberately unattached; MTC0 must report ready.
        movei 1,2
        movei 4,1
        pushj 017,mtc_service
        trne 1,0000002
        jrst fail17
        setz 1,
        movei 4,1
        pushj 017,mtc_service
        trnn 1,0000002
        jrst fail17

        ; Write record A.
        setz 1,
        movei 2,record_a
        movei 3,4
        seto 4,
        pushj 017,mtc_service
        jumpe 1,write_a_ok
        movei 1,1
        popj 017,
write_a_ok:
        ; Write record B.
        setz 1,
        movei 2,record_b
        movei 3,3
        seto 4,
        pushj 017,mtc_service
        jumpe 1,write_b_ok
        movei 1,2
        popj 017,
write_b_ok:
        ; Write tape mark on MTC0, then rewind through production control.
        setz 1,
        movei 4,0001400
        pushj 017,mtc_service
        jumpn 1,fail3
        setz 1,
        movei 4,0000400
        pushj 017,mtc_service
        jumpn 1,fail4

        ; Read A with a larger maximum and verify EOR stops before sentinel.
        movei 1,read_a
        movei 2,010
        move 3,[012345670123]
fill_a:
        movem 3,(1)
        aoj 1,
        sojg 2,fill_a
        setz 1,
        movei 2,read_a
        movei 3,010
        setz 4,
        pushj 017,mtc_service
        jumpe 1,read_a_ok
        movei 1,5
        popj 017,
read_a_ok:
        movei 1,record_a
        movei 2,read_a
        movei 3,4
        pushj 017,compare_words
        jumpe 1,read_a_cmp_ok
        movei 1,6
        popj 017,
read_a_cmp_ok:
        move 1,read_a+4
        came 1,[012345670123]
        jrst fail7

        ; Space forward over B and read the tape mark.  Current production
        ; read reports an error, while Type-516 status must identify EOF.
        setz 1,
        movei 4,0003000
        pushj 017,mtc_service
        jumpn 1,fail8
        setz 1,
        movei 2,read_eof
        movei 3,2
        setz 4,
        pushj 017,mtc_service
        came 1,[-5]
        jrst fail9
        setz 1,
        movei 4,1
        pushj 017,mtc_service
        trnn 1,0000400
        jrst fail10

        ; Rewind, space over A, and prove B is the next readable record.
        setz 1,
        movei 4,0000400
        pushj 017,mtc_service
        jumpn 1,fail11
        setz 1,
        movei 4,0003000
        pushj 017,mtc_service
        jumpn 1,fail12
        movei 1,read_b
        movei 2,010
        move 3,[076543210765]
fill_b:
        movem 3,(1)
        aoj 1,
        sojg 2,fill_b
        setz 1,
        movei 2,read_b
        movei 3,010
        setz 4,
        pushj 017,mtc_service
        jumpe 1,read_b_ok
        movei 1,13
        popj 017,
read_b_ok:
        movei 1,record_b
        movei 2,read_b
        movei 3,3
        pushj 017,compare_words
        jumpe 1,eot_test
        movei 1,14
        popj 017,

        ; MTC1 is a sparse 1 MB tape with capacity set to 1 MB.  One forward
        ; space reaches/passes that capacity; the controller must expose EOT.
eot_test:
        movei 1,1
        movei 4,0003000
        pushj 017,mtc_service
        jumpn 1,fail15
        movei 1,1
        movei 4,1
        pushj 017,mtc_service
        trnn 1,0010000
        jrst fail15

        ; Production space-to-filemark must also terminate successfully.
        setz 1,
        movei 4,0000400
        pushj 017,mtc_service
        jumpn 1,fail16
        setz 1,
        movei 4,0007000
        pushj 017,mtc_service
        jumpn 1,fail16
        setz 1,
        popj 017,

; AC1 expected, AC2 actual, AC3 count. Return AC1=0 equal, 1 mismatch.
compare_words:
        move 4,(1)
        came 4,(2)
        jrst compare_bad
        aoj 1,
        aoj 2,
        sojg 3,compare_words
        setz 1,
        popj 017,
compare_bad:
        movei 1,1
        popj 017,

fail3:  movei 1,3
        popj 017,
fail4:  movei 1,4
        popj 017,
fail7:  movei 1,7
        popj 017,
fail8:  movei 1,010
        popj 017,
fail9:  movei 1,011
        popj 017,
fail10: movei 1,10
        popj 017,
fail11: movei 1,11
        popj 017,
fail12: movei 1,12
        popj 017,
fail15: movei 1,15
        popj 017,
fail16: movei 1,16
        popj 017,
fail17: movei 1,17
        popj 017,

mtc_test_pi3:
        .word 0
        movem 1,pi3_ac1
        movem 2,pi3_ac2
        movem 3,pi3_ac3
        pushj 017,storage_dct_handler
        move 1,pi3_ac1
        move 2,pi3_ac2
        move 3,pi3_ac3
        jrst 010,@mtc_test_pi3

mtc_test_pi5:
        .word 0
        movem 1,pi5_ac1
        movem 2,pi5_ac2
        movem 3,pi5_ac3
        pushj 017,storage_pi_handler
        move 1,pi5_ac1
        move 2,pi5_ac2
        move 3,pi5_ac3
        jrst 010,@mtc_test_pi5

record_a:
        .word 001234567012
        .word 076543210765
        .word 000000000001
        .word 077777777777
record_b:
        .word 011111111111
        .word 022222222222
        .word 033333333333

        .bss
pi3_ac1: .block 1
pi3_ac2: .block 1
pi3_ac3: .block 1
pi5_ac1: .block 1
pi5_ac2: .block 1
pi5_ac3: .block 1
read_a: .block 010
read_b: .block 010
read_eof: .block 2
        .globl __test_exit
__test_exit: .block 1
