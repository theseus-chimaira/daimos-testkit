; Native RC10 leaf with real PI2/PI6, using the production descriptor,
; clock router and counters. Only process wake/wait stubbed.
        .text
        .globl start
        .globl passed
        .globl recover
        .globl raw
        .globl op
        .globl runtime
        .globl target
        .globl result
        .globl elapsed
        .globl ticks
        .globl wakes
        .globl pi_count
        .globl buffer
        .globl proc_table
        .globl proc_wait_event
        .globl proc_wakeup_event
        .globl pdp10_pi_dispatch_done
        .globl pdp10_pi_handler_return
start:
        move 17,[-01000,,stack-1]
        move 1,runtime
        movem 1,proc_table
        movei 1,drm236_watchdog_tick_v1079
        hrrm 1,storage_clock_drm_jump
        move 1,[jsr disk_pi]
        movem 1,044
        move 1,[jsr clock_pi]
        movem 1,054
        cono 4,010000
        cono 4,002242
        cono 0,003006
recover:
        move 1,ticks
        movem 1,elapsed
        move 1,raw
        move 2,target
        skipe op
        jrst write_test
        pushj 17,drm236_read_block_service
        jrst done
write_test:
        pushj 17,drm236_write_block_service
done:
        movem 1,result
        move 1,ticks
        subm 1,elapsed
passed:
        halt .
disk_pi:
        .word 0
        movem 1,pi2a
        movem 2,pi2b
        movem 3,pi2c
        aos pi_count
        pushj 17,drm236_pi_handler
        move 1,pi2a
        move 2,pi2b
        move 3,pi2c
        jrst 012,@disk_pi
clock_pi:
        .word 0
        movem 1,pi6a
        movem 2,pi6b
        movem 3,pi6c
        cono 0,003006
        aos ticks
        pushj 17,storage_clock_tick
        move 1,pi6a
        move 2,pi6b
        move 3,pi6c
        jrst 012,@clock_pi
proc_wait_event:
        skipn (1)
        jrst proc_wait_event
        popj 17,
proc_wakeup_event:
        aos wakes
pdp10_pi_dispatch_done:
pdp10_pi_handler_return:
        popj 17,
        .data
raw:    .word 0
op:     .word 0
runtime:.word 0
target: .word buffer
        .bss
proc_table: .block 1
result: .block 1
elapsed:.block 1
ticks:  .block 1
wakes:  .block 1
pi_count: .block 1
pi2a: .block 1
pi2b: .block 1
pi2c: .block 1
pi6a: .block 1
pi6b: .block 1
pi6c: .block 1
guard_before: .block 1
buffer: .block 0200
guard_after: .block 1
stack: .block 01000
