        .text
        .globl main
        .globl __test_exit
        .globl logstore_mres_dispatch
        .globl logstore_mres_state
        .globl logstore_backend_read_jump
        .globl logstore_backend_write_jump
        .globl kret_neg1
        .globl proc_wait_event
        .globl proc_wakeup_event

main:
        ; Patch the production backend jump slots to this in-memory oracle.
        movei   1,test_read
        hrrm    1,logstore_backend_read_jump
        movei   1,test_write
        hrrm    1,logstore_backend_write_jump

        ; Runtime state: root logical start 10, six LOGSTORE blocks, next
        ; sequence 5, capacity four, producer slot one, BLOCKSET mode.
        movei   1,012
        movem   1,logstore_mres_state
        movei   1,6
        movem   1,logstore_mres_state+1
        movei   1,5
        movem   1,logstore_mres_state+2
        move    1,[4,,1]
        movem   1,logstore_mres_state+3
        setzm   logstore_mres_state+4
        setzm   write_count
        setzm   wake_count
        setzm   wait_count
        setzm   logstore_mres_state+5

        ; Caller supplies timestamp, packed metadata, and two payload words.
        move    1,[012345670123]
        movem   1,record+2
        movei   1,2                    ; two payload words
        movem   1,record+3
        movei   1,0111
        movem   1,record+4
        movei   1,0222
        movem   1,record+5
        movei   1,record
        movei   5,4
        pushj   17,logstore_mres_dispatch
        jumpn   1,fail1

        ; Slot one maps to relative block three, then root start 012 => 015.
        move    1,last_block
        caie    1,015
        jrst    fail2
        move    1,write_count
        caie    1,1
        jrst    fail3
        move    1,record
        camn    1,[0546362454321]
        jrst    chkseq
        jrst    fail4
chkseq:
        move    1,record+1
        caie    1,5
        jrst    fail5
        move    1,record+0177
        camn    1,[0231413323451]
        jrst    chkstate
        jrst    fail6
chkstate:
        move    1,logstore_mres_state+2
        caie    1,6
        jrst    fail7
        hrrz    1,logstore_mres_state+3
        caie    1,2
        jrst    fail8
        move    1,wake_count
        caie    1,1
        jrst    fail17
        skipn   logstore_mres_state+5
        jrst    fail18

        ; WAIT with a stale sequence must not sleep.
        movei   1,5
        movei   5,5
        pushj   17,logstore_mres_dispatch
        jumpn   1,fail19
        skipe   wait_count
        jrst    fail20

        ; WAIT with the current sequence clears the event and arms the wait.
        movei   1,6
        movei   5,5
        pushj   17,logstore_mres_dispatch
        jumpn   1,fail21
        move    1,wait_count
        caie    1,1
        jrst    fail22

        ; STATUS returns the producer cursor and capacity/slot pair.
        movei   5,1
        pushj   17,logstore_mres_dispatch
        caie    1,6
        jrst    fail9
        camn    2,[4,,2]
        jrst    chkstatusblocks
        jrst    fail10
chkstatusblocks:
        caie    3,6
        jrst    fail11

        ; Raw read of relative block three must retrieve the just-written
        ; record from the oracle media block.
        movei   1,3
        movei   2,readback
        movei   5,2
        pushj   17,logstore_mres_dispatch
        jumpn   1,fail12
        move    1,readback+1
        caie    1,5
        jrst    fail13
        move    1,readback+0177
        camn    1,[0231413323451]
        jrst    badlength
        jrst    fail14

badlength:
        ; Payload length 124 is invalid and must not reach the backend.
        move    1,[0174]
        movem   1,record+3
        movei   1,record
        movei   5,4
        pushj   17,logstore_mres_dispatch
        jumpge  1,fail15
        move    1,write_count
        caie    1,1
        jrst    fail16

        setz    1,
        popj    17,

; BLOCKSET-style backend oracle: AC1=root logical block, AC2=buffer.
test_write:
        movem   1,last_block
        aos     write_count
        movei   3,media
        movei   4,0200
copy_write:
        move    5,(2)
        movem   5,(3)
        addi    2,1
        addi    3,1
        sojg    4,copy_write
        setz    1,
        popj    17,

test_read:
        movem   1,last_block
        movei   3,media
        movei   4,0200
copy_read:
        move    5,(3)
        movem   5,(2)
        addi    2,1
        addi    3,1
        sojg    4,copy_read
        setz    1,
        popj    17,

kret_neg1:
        seto    1,
        popj    17,

proc_wakeup_event:
        aos     wake_count
        popj    17,

proc_wait_event:
        aos     wait_count
        popj    17,

fail1:  movei 1,1
        popj 17,
fail2:  movei 1,2
        popj 17,
fail3:  movei 1,3
        popj 17,
fail4:  movei 1,4
        popj 17,
fail5:  movei 1,5
        popj 17,
fail6:  movei 1,6
        popj 17,
fail7:  movei 1,7
        popj 17,
fail8:  movei 1,010
        popj 17,
fail9:  movei 1,011
        popj 17,
fail10: movei 1,012
        popj 17,
fail11: movei 1,013
        popj 17,
fail12: movei 1,014
        popj 17,
fail13: movei 1,015
        popj 17,
fail14: movei 1,016
        popj 17,
fail15: movei 1,017
        popj 17,
fail16: movei 1,020
        popj 17,
fail17: movei 1,021
        popj 17,
fail18: movei 1,022
        popj 17,
fail19: movei 1,023
        popj 17,
fail20: movei 1,024
        popj 17,
fail21: movei 1,025
        popj 17,
fail22: movei 1,026
        popj 17,

        .bss
record:      .block 0200
readback:    .block 0200
media:       .block 0200
last_block:  .block 1
write_count: .block 1
wake_count:  .block 1
wait_count:  .block 1
__test_exit: .block 1
