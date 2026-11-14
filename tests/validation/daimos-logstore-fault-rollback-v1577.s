; Native PDP-6 source-linked LOGSTORE write-failure and retry oracle.
; Uses the production runtime MRES (no reimplemented append logic).
; Test-only physical block oracle writes an invalid final trailer on
; the first transfer, then reports error. Retry copies full record.
        .text
        .globl main
        .globl __test_exit
        .globl logstore_mres_dispatch
        .globl logstore_mres_state
        .globl logstore_backend_read_call
        .globl logstore_backend_write_jump
        .globl kret_neg1
        .globl proc_wait_event
        .globl proc_wakeup_event

main:
        movei   1,test_read_v1577
        hrrm    1,logstore_backend_read_call
        movei   1,test_write_v1577
        hrrm    1,logstore_backend_write_jump
        movei   1,012
        movem   1,logstore_mres_state
        movei   1,6
        movem   1,logstore_mres_state+1
        movei   1,5
        movem   1,logstore_mres_state+2
        move    1,[4,,1]
        movem   1,logstore_mres_state+3
        setzm   logstore_mres_state+4
        setzm   logstore_mres_state+5
        setom   logstore_mres_state+6
        setzm   attempts_v1577
        setzm   wakes_v1577
        setzm   sleeps_v1577

        movei   1,2
        movem   1,record_v1577+3
        movei   1,0157601
        movem   1,record_v1577+4
        move    1,[045671234567]
        movem   1,record_v1577+5

        ; Real production APPEND should fail after the block oracle
        ; has written exactly one uncommitted version of that record.
        movei   1,record_v1577
        movei   5,4
        pushj   17,logstore_mres_dispatch
        jumpge  1,fail1_v1577
        move    1,attempts_v1577
        caie    1,1
        jrst    fail2_v1577
        move    1,last_block_v1577
        caie    1,015
        jrst    fail3_v1577
        move    1,logstore_mres_state+2
        caie    1,5
        jrst    fail4_v1577
        move    1,logstore_mres_state+3
        came    1,[4,,1]
        jrst    fail5_v1577
        skipe   wakes_v1577
        jrst    fail6_v1577
        skipe   logstore_mres_state+5
        jrst    fail7_v1577
        move    1,media_v1577
        came    1,[0546362454321]
        jrst    fail8_v1577
        move    1,media_v1577+1
        caie    1,5
        jrst    fail9_v1577
        skipe   media_v1577+0177
        jrst    fail10_v1577

        ; Exactly the same slot and sequence must be retried, with
        ; physically committed data and exactly one producer wake.
        movei   1,record_v1577
        movei   5,4
        pushj   17,logstore_mres_dispatch
        jumpn   1,fail11_v1577
        move    1,attempts_v1577
        caie    1,2
        jrst    fail12_v1577
        move    1,logstore_mres_state+2
        caie    1,6
        jrst    fail13_v1577
        move    1,logstore_mres_state+3
        came    1,[4,,2]
        jrst    fail14_v1577
        move    1,wakes_v1577
        caie    1,1
        jrst    fail15_v1577
        skipn   logstore_mres_state+5
        jrst    fail16_v1577
        move    1,media_v1577+0177
        came    1,[0231413323451]
        jrst    fail17_v1577

        ; Read through original LOGSTORE MRES, never directly from the
        ; backing oracle on the successful retry.
        movei   1,3
        movei   2,readback_v1577
        movei   5,2
        pushj   17,logstore_mres_dispatch
        jumpn   1,fail18_v1577
        move    1,readback_v1577+1
        caie    1,5
        jrst    fail19_v1577
        move    1,readback_v1577+0177
        came    1,[0231413323451]
        jrst    fail20_v1577
        setz    1,
        popj    17,

test_write_v1577:
        movem   1,last_block_v1577
        aos     attempts_v1577
        movei   3,media_v1577
        movei   4,0200
test_write_loop_v1577:
        move    5,(2)
        movem   5,(3)
        addi    2,1
        addi    3,1
        sojg    4,test_write_loop_v1577
        move    1,attempts_v1577
        caie    1,1
        jrst    test_write_ok_v1577
        setzm   media_v1577+0177
        seto    1,
        popj    17,
test_write_ok_v1577:
        setz    1,
        popj    17,

test_read_v1577:
        movei   3,media_v1577
        movei   4,0200
test_read_loop_v1577:
        move    5,(3)
        movem   5,(2)
        addi    2,1
        addi    3,1
        sojg    4,test_read_loop_v1577
        setz    1,
        popj    17,

kret_neg1:
        seto    1,
        popj    17,
proc_wait_event:
        aos     sleeps_v1577
        popj    17,
proc_wakeup_event:
        aos     wakes_v1577
        popj    17,

fail1_v1577:  movei 1,1
              popj 17,
fail2_v1577:  movei 1,2
              popj 17,
fail3_v1577:  movei 1,3
              popj 17,
fail4_v1577:  movei 1,4
              popj 17,
fail5_v1577:  movei 1,5
              popj 17,
fail6_v1577:  movei 1,6
              popj 17,
fail7_v1577:  movei 1,7
              popj 17,
fail8_v1577:  movei 1,010
              popj 17,
fail9_v1577:  movei 1,011
              popj 17,
fail10_v1577: movei 1,012
              popj 17,
fail11_v1577: movei 1,013
              popj 17,
fail12_v1577: movei 1,014
              popj 17,
fail13_v1577: movei 1,015
              popj 17,
fail14_v1577: movei 1,016
              popj 17,
fail15_v1577: movei 1,017
              popj 17,
fail16_v1577: movei 1,020
              popj 17,
fail17_v1577: movei 1,021
              popj 17,
fail18_v1577: movei 1,022
              popj 17,
fail19_v1577: movei 1,023
              popj 17,
fail20_v1577: movei 1,024
              popj 17,

        .bss
record_v1577:       .block 0200
media_v1577:        .block 0200
readback_v1577:     .block 0200
last_block_v1577:   .block 1
attempts_v1577:     .block 1
wakes_v1577:        .block 1
sleeps_v1577:       .block 1
__test_exit:        .block 1
