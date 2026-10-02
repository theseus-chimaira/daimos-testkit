        .text
        .globl main
        .globl fail_id
        .globl __test_exit
        .globl drm236_read_block
        .globl drm236_write_block
        .globl drm236_read_jump
        .globl drm236_write_jump
        .globl drm236_read_block_service
        .globl drm236_write_block_service
        .globl drm236_pi_handler
        .globl proc_table
        .globl mfsdev_drm_reads
        .globl mfsdev_drm_writes
        .globl mfsdev_storage_errors
        .globl drm_test_inject_pending
        .globl drm_test_nested_result

main:
        setzm fail_id
        movei 1,drm236_read_block_service
        hrrm 1,drm236_read_jump
        movei 1,drm236_write_block_service
        hrrm 1,drm236_write_jump

        ; Unit 0, ordinary block.
        movei 4,buffer
        movei 5,0200
        movei 6,012345
fill0:
        movem 6,(4)
        addi 6,010101
        addi 4,1
        sojg 5,fill0
        setz 1,
        movei 2,7
        movei 3,buffer
        pushj 17,drm236_write_block
        jumpn 1,fail1
        movei 4,buffer
        movei 5,0200
clear0:
        setzm (4)
        addi 4,1
        sojg 5,clear0
        setz 1,
        movei 2,7
        movei 3,buffer
        pushj 17,drm236_read_block
        jumpn 1,fail2
        movei 4,buffer
        movei 5,0200
        movei 6,012345
check0:
        came 6,(4)
        jrst fail3
        addi 6,010101
        addi 4,1
        sojg 5,check0

        ; Unit 3, last legal 128-word block.  This also verifies the two
        ; high unit bits in the Type-236 18-bit address register.
        movei 4,buffer
        movei 5,0200
        movei 6,076543
fill3:
        movem 6,(4)
        subi 6,000111
        addi 4,1
        sojg 5,fill3
        movei 1,3
        movei 2,017777
        movei 3,buffer
        pushj 17,drm236_write_block
        jumpn 1,fail4
        movei 4,buffer
        movei 5,0200
clear3:
        setzm (4)
        addi 4,1
        sojg 5,clear3
        movei 1,3
        movei 2,017777
        movei 3,buffer
        pushj 17,drm236_read_block
        jumpn 1,fail5
        movei 4,buffer
        movei 5,0200
        movei 6,076543
check3:
        came 6,(4)
        jrst fail6
        subi 6,000111
        addi 4,1
        sojg 5,check3

        ; Public veneer argument checks.
        movei 1,4
        setz 2,
        movei 3,buffer
        pushj 17,drm236_read_block
        camn 1,[-1]
        jrst arg2
        jrst fail7
arg2:
        setz 1,
        movei 2,020000
        movei 3,buffer
        pushj 17,drm236_read_block
        camn 1,[-1]
        jrst arg3
        jrst fail8
arg3:
        setz 1,
        setz 2,
        setz 3,
        pushj 17,drm236_read_block
        camn 1,[-1]
        jrst runtime_test
        jrst fail9

        ; Runtime path: enable PI2 and force proc_table nonzero.  One write and
        ; one read must each generate the Type-167 completion interrupt and
        ; the following Type-236 completion interrupt.
runtime_test:
        move 1,[jsr drm_test_pi2]
        movem 1,000044
        cono 0004,010000
        movei 1,002240
        cono 0004,0(1)
        setom proc_table
        setzm pi2_count

        movei 4,buffer
        movei 5,0200
        movei 6,055555
runtime_fill:
        movem 6,(4)
        addi 6,000123
        addi 4,1
        sojg 5,runtime_fill
        movei 1,1
        movei 2,1
        movei 3,buffer
        pushj 17,drm236_write_block
        jumpn 1,fail10
        movei 4,buffer
        movei 5,0200
runtime_clear:
        setzm (4)
        addi 4,1
        sojg 5,runtime_clear
        movei 1,1
        movei 2,1
        movei 3,buffer
        pushj 17,drm236_read_block
        jumpn 1,fail11
        move 1,pi2_count
        caie 1,4
        jrst fail12
        movei 4,buffer
        movei 5,0200
        movei 6,055555
runtime_check:
        came 6,(4)
        jrst fail13
        addi 6,000123
        addi 4,1
        sojg 5,runtime_check

        ; Force a real overlapping runtime request.  proc_wait_event injects a
        ; nested read while this write owns the Type-167/236 engine.  The read
        ; must occupy drm236_pending_request and start from the write-completion
        ; PI without relying on rotational or timer assumptions.
        setzm pi2_count
        setzm drm_test_nested_result
        setom drm_test_inject_pending
        movei 1,1
        movei 2,3
        movei 3,buffer
        pushj 17,drm236_write_block
        jumpn 1,fail14
        skipn drm_test_nested_result
        jrst runtime_queue_count
        jrst fail15
runtime_queue_count:
        move 1,pi2_count
        caie 1,4
        jrst fail16

        ; Two polled transfers, one ordinary runtime read/write pair, and the
        ; queued runtime write/read pair completed successfully.
        move 1,mfsdev_drm_reads
        caie 1,4
        jrst fail17
        move 1,mfsdev_drm_writes
        caie 1,4
        jrst fail18
        skipn mfsdev_storage_errors+5
        jrst pass
        jrst fail19

pass:
        setz 1,
        popj 17,

fail1:  movei 1,1
        jrst fail
fail2:  movei 1,2
        jrst fail
fail3:  movei 1,3
        jrst fail
fail4:  movei 1,4
        jrst fail
fail5:  movei 1,5
        jrst fail
fail6:  movei 1,6
        jrst fail
fail7:  movei 1,7
        jrst fail
fail8:  movei 1,010
        jrst fail
fail9:  movei 1,011
        jrst fail
fail10: movei 1,012
        jrst fail
fail11: movei 1,013
        jrst fail
fail12: movei 1,014
        jrst fail
fail13: movei 1,015
        jrst fail
fail14: movei 1,016
        jrst fail
fail15: movei 1,017
        jrst fail
fail16: movei 1,020
        jrst fail
fail17: movei 1,021
        jrst fail
fail18: movei 1,022
        jrst fail
fail19: movei 1,023
fail:   movem 1,fail_id
        popj 17,

; PI2 wrapper preserves the production AC1..AC3 interrupt ABI.
drm_test_pi2:
        .word 0
        movem 1,pi2_ac1
        movem 2,pi2_ac2
        movem 3,pi2_ac3
        aos pi2_count
        pushj 17,drm236_pi_handler
        move 1,pi2_ac1
        move 2,pi2_ac2
        move 3,pi2_ac3
        jrst 012,@drm_test_pi2

        .bss
pi2_ac1:    .block 1
pi2_ac2:    .block 1
pi2_ac3:    .block 1
pi2_count:  .block 1
fail_id:     .block 1
__test_exit: .block 1
buffer:      .block 0200
