; Verify that a host-built TSFS image is readable by the production Type-551
; block driver.  This is a media/driver compatibility test, not a filesystem
; mount test.
        .text
        .globl main
        .globl storage_pi_handler
        .globl storage_dct_handler
        .globl storage_pi_tape_jump
        .globl storage_dct_tape_jump
        .globl tape_pi_handler
        .globl tape_dct_handler
        .globl dtc_read_block

main:
        movei 1,tape_pi_handler
        hrrm 1,storage_pi_tape_jump
        movei 1,tape_dct_handler
        hrrm 1,storage_dct_tape_jump

        move 1,[jsr tsfs_test_pi3]
        movem 1,000047
        move 1,[jsr tsfs_test_pi5]
        movem 1,000052
        setzm 000046
        cono 0004,010000
        movei 1,002224
        cono 0004,0(1)

        ; Primary member descriptor at block 1.  Block 0 is reserved.
        setz 1,
        movei 2,1
        movei 3,read_buf
        pushj 017,dtc_read_block
        jumpn 1,read_fail
        move 1,read_buf
        came 1,[646346630000]         ; SIXBIT "TSFS  "
        jrst magic_fail

        ; Minimal table directory at block 3.
        setz 1,
        movei 2,3
        movei 3,read_buf
        pushj 017,dtc_read_block
        jumpn 1,tdir_read_fail
        move 1,read_buf
        came 1,[646344516200]         ; SIXBIT "TSDIR "
        jrst tdir_magic_fail
        setz 1,
        popj 017,

read_fail:       movei 1,1
        popj 017,
magic_fail:      movei 1,2
        popj 017,
tdir_read_fail:  movei 1,3
        popj 017,
tdir_magic_fail: movei 1,4
        popj 017,

tsfs_test_pi3:
        .word 0
        movem 1,pi3_ac1
        movem 2,pi3_ac2
        movem 3,pi3_ac3
        pushj 017,storage_dct_handler
        move 1,pi3_ac1
        move 2,pi3_ac2
        move 3,pi3_ac3
        jrst 010,@tsfs_test_pi3

tsfs_test_pi5:
        .word 0
        movem 1,pi5_ac1
        movem 2,pi5_ac2
        movem 3,pi5_ac3
        pushj 017,storage_pi_handler
        move 1,pi5_ac1
        move 2,pi5_ac2
        move 3,pi5_ac3
        jrst 010,@tsfs_test_pi5

        .bss
pi3_ac1:        .block 1
pi3_ac2:        .block 1
pi3_ac3:        .block 1
pi5_ac1:        .block 1
pi5_ac2:        .block 1
pi5_ac3:        .block 1
read_buf:       .block 0200
        .bss
        .globl __test_exit
__test_exit:     .block 1
