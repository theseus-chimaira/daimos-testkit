; Direct Type-551 single-block reverse read/write test.
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
        movei 1,tape_pi_handler
        hrrm 1,storage_pi_tape_jump
        movei 1,tape_dct_handler
        hrrm 1,storage_dct_tape_jump

        move 1,[jsr dtc_test_pi3]
        movem 1,000047
        move 1,[jsr dtc_test_pi5]
        movem 1,000052
        setzm 000046
        cono 0004,010000
        movei 1,002224
        cono 0004,0(1)

        ; A = 1..128, C = 01001..01200, B is just positioning data.
        movei 1,buf_a
        movei 2,1
        movei 3,0200
fill_a:
        movem 2,(1)
        aoj 1,
        aoj 2,
        sojg 3,fill_a
        movei 1,buf_b
        movei 2,0401
        movei 3,0200
fill_b:
        movem 2,(1)
        aoj 1,
        aoj 2,
        sojg 3,fill_b
        movei 1,buf_c
        movei 2,01001
        movei 3,0200
fill_c:
        movem 2,(1)
        aoj 1,
        aoj 2,
        sojg 3,fill_c

        ; Write target then the following block.  The second operation leaves
        ; the transport beyond block 0200 and moving forward.
        setz 1,
        movei 2,0200
        movei 3,buf_a
        pushj 017,dtc_write_block
        jumpe 1,w1_ok
        movei 1,1
        popj 017,
w1_ok:
        setz 1,
        movei 2,0201
        movei 3,buf_b
        pushj 017,dtc_write_block
        jumpe 1,w2_ok
        movei 1,2
        popj 017,
w2_ok:
        ; Single-block read of 0200 should be selected as a reverse transfer.
        setz 1,
        movei 2,0200
        movei 3,read_buf
        pushj 017,dtc_read_block
        jumpe 1,rr_ok
        movei 1,3
        popj 017,
rr_ok:
        movei 1,buf_a
        movei 2,read_buf
        movei 3,0200
cmp_a:
        move 4,(1)
        came 4,(2)
        jrst fail_read
        aoj 1,
        aoj 2,
        sojg 3,cmp_a

        ; Move forward to 0201 again, then overwrite 0200 while approaching
        ; it in reverse.  This exercises the reverse DATAO path.
        setz 1,
        movei 2,0201
        movei 3,read_buf
        pushj 017,dtc_read_block
        jumpe 1,pos_ok
        movei 1,5
        popj 017,
pos_ok:
        setz 1,
        movei 2,0200
        movei 3,buf_c
        pushj 017,dtc_write_block
        jumpe 1,rw_ok
        movei 1,6
        popj 017,
rw_ok:
        ; Read target again and verify the reverse write persisted.
        setz 1,
        movei 2,0200
        movei 3,read_buf
        pushj 017,dtc_read_block
        jumpe 1,verify_ok
        movei 1,7
        popj 017,
verify_ok:
        movei 1,buf_c
        movei 2,read_buf
        movei 3,0200
cmp_c:
        move 4,(1)
        came 4,(2)
        jrst fail_write
        aoj 1,
        aoj 2,
        sojg 3,cmp_c
        setz 1,
        popj 017,
fail_read:
        movei 1,4
        popj 017,
fail_write:
        movei 1,010
        popj 017,

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
pi3_ac1: .block 1
pi3_ac2: .block 1
pi3_ac3: .block 1
pi5_ac1: .block 1
pi5_ac2: .block 1
pi5_ac3: .block 1
buf_a: .block 0200
buf_b: .block 0200
buf_c: .block 0200
read_buf: .block 0200
        .globl __test_exit
__test_exit: .block 1
