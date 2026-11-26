; Native production DSK runtime queue after a lost WRITE.
; Real hardware command state and real 60Hz APR clock. No fabricated IDS.
        .text
        .globl start
        .globl loss_gate
        .globl passed
        .globl failed
        .globl dsk_read_sector
        .globl dsk_enqueue
        .globl dsk_queue
        .globl dsk_watchdog_tick
        .globl storage_clock_tick
        .globl storage_clock_dsk_jump
        .globl storage_count
        .globl storage_state
        .globl storage_iowd
        .globl proc_table
        .globl mfsdev_storage_errors
        .globl proc_wakeup_event
        .globl proc_wait_event
        .globl pdp10_pi_dispatch_done
        .globl pdp10_pi_handler_return
        .globl ticks
        .globl wakes
        .globl req_a
        .globl req_b
start:
        move 17,[-01000,,stack-1]
        setom proc_table
        movei 1,dsk_watchdog_tick
        hrrm 1,storage_clock_dsk_jump
        move 1,[jsr clock_pi]
        movem 1,000054
        cono 0004,010000
        cono 0004,002202
        cono 0000,003006
        setz 1,
        datao 0270,1
ready:
        coni 0270,2
        trnn 2,040000
        jrst ready
        cono 0270,02000
sector:
        coni 0270,2
        trnn 2,004000
        jrst sector
loss_gate:
        ; Harness detaches selected DSK0 and attaches a distinct file.
        ; Clear flags and request END. With no old sector clocks, SCS
        ; remains. Do not issue any other DATAO until a legal state.
        cono 0270,030200
        move 1,[012345,,065432]
        movem 1,storage_iowd
        movei 1,req_a
        pushj 17,dsk_enqueue
        jumpn 1,failed
        movei 1,req_b
        pushj 17,dsk_enqueue
        jumpn 1,failed
        move 1,ticks
        movem 1,started
        ; Slot0 drains both older unit1 requests, then its own request.
        movei 1,0200020
        movei 2,buffer
        pushj 17,dsk_read_sector
        came 1,[-5]
        jrst failed
        move 1,req_a+2
        came 1,[-1]
        jrst failed
        move 1,req_b+2
        came 1,[-1]
        jrst failed
        skipn dsk_queue+1
        jrst queue_empty
        jrst failed
queue_empty:
        move 1,storage_iowd
        came 1,[012345,,065432]
        jrst failed
        skipn storage_count
        skipe storage_state
        jrst failed
        move 1,mfsdev_storage_errors+2
        caie 1,3
        jrst failed
        move 1,wakes
        caie 1,3
        jrst failed
        move 1,ticks
        sub 1,started
        cail 1,01604
        caile 1,01607
        jrst failed
        coni 0270,2
        trnn 2,004000
        jrst failed
passed:
        setz 1,
        halt .
failed:
        movei 1,1
        halt .
clock_pi:
        .word 0
        movem 1,saved1
        movem 2,saved2
        movem 3,saved3
        cono 0000,003006
        aos ticks
        pushj 17,storage_clock_tick
        move 1,saved1
        move 2,saved2
        move 3,saved3
        jrst 010,@clock_pi
proc_wakeup_event:
        aos wakes
        popj 17,
proc_wait_event:
pdp10_pi_dispatch_done:
pdp10_pi_handler_return:
        popj 17,
        .data
req_a: .word 0200000,,buffer
       .word 0
       .word 0
req_b: .word 0200001,,buffer
       .word 0
       .word 0
        .bss
        .globl proc_current_slot
proc_current_slot: .block 1
proc_table: .block 1
ticks: .block 1
wakes: .block 1
started: .block 1
saved1: .block 1
saved2: .block 1
saved3: .block 1
buffer: .block 0200
stack: .block 01000
