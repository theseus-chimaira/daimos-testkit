; Real runtime READ, PI3/DCT and PI5 completion, followed by queued
; peer requests. Fault mode masks PI5 only for the first operation.
        .text
        .globl start
        .globl silent_start
        .globl passed
        .globl failed
        .globl ticks
        .globl first_elapsed
        .globl wakes
        .globl dsk_read_sector
        .globl dsk_enqueue
        .globl dsk_queue
        .globl dsk_watchdog_tick
        .globl dsk_pi_handler
        .globl dsk_dct_handler
        .globl storage_pi_handler
        .globl storage_dct_handler
        .globl storage_pi_dsk_jump
        .globl storage_dct_dsk_jump
        .globl storage_clock_tick
        .globl storage_clock_dsk_jump
        .globl storage_state
        .globl storage_count
        .globl proc_table
        .globl proc_wakeup_event
        .globl proc_wait_event
        .globl pdp10_pi_dispatch_done
        .globl pdp10_pi_handler_return
        .globl mfsdev_io_in
        .globl mfsdev_storage_errors
start:
        setzm silent
        jrst initialize
silent_start:
        setom silent
initialize:
        move 17,[-01000,,stack-1]
        setom proc_table
        movei 1,dsk_pi_handler
        hrrm 1,storage_pi_dsk_jump
        movei 1,dsk_dct_handler
        hrrm 1,storage_dct_dsk_jump
        movei 1,dsk_watchdog_tick
        hrrm 1,storage_clock_dsk_jump
        move 1,[jsr data_pi]
        movem 1,000047
        move 1,[jsr disk_pi]
        movem 1,000052
        move 1,[jsr clock_pi]
        movem 1,000054
        cono 0004,010000
        skipn silent
        jrst enable_all
        cono 0004,002222          ; PI3/6, first PI5 deliberately masked
        jrst enable_clock
enable_all:
        cono 0004,002226          ; PI3/5/6
enable_clock:
        cono 0000,003006
        movei 1,req_bad
        pushj 17,dsk_enqueue
        jumpn 1,failed
        movei 1,req_a
        pushj 17,dsk_enqueue
        jumpn 1,failed
        movei 1,req_b
        pushj 17,dsk_enqueue
        jumpn 1,failed
        move 1,ticks
        movem 1,started
        movei 1,0200002
        movei 2,buf_c
        pushj 17,dsk_read_sector
        jumpn 1,failed
        move 1,req_bad+2
        came 1,[-1]
        jrst failed
        move 1,req_a+2
        caie 1,1
        jrst failed
        move 1,req_b+2
        caie 1,1
        jrst failed
        skipe dsk_queue
        jrst failed
        skipe dsk_queue+1
        jrst failed
        skipe storage_count
        jrst failed
        skipe storage_state
        jrst failed
        move 1,mfsdev_storage_errors+2
        caie 1,1
        jrst failed
        move 1,mfsdev_io_in+016
        caie 1,3
        jrst failed
        move 1,wakes
        caie 1,4
        jrst failed
        skipn silent
        jrst check_buffers
        move 1,first_elapsed
        caie 1,0454
        jrst failed
check_buffers:
        movei 1,buf_a
        movei 4,040
        movei 5,3
check_sector:
        movei 2,0200
check_words:
        move 3,(1)
        came 3,4
        jrst failed
        aoj 1,
        sojg 2,check_words
        aoj 4,
        sojg 5,check_sector
passed:
        setz 1,
        halt .
failed:
        movei 1,1
        halt .
data_pi:
        .word 0
        movem 1,pi3a
        movem 2,pi3b
        pushj 17,storage_dct_handler
        move 1,pi3a
        move 2,pi3b
        jrst 010,@data_pi
disk_pi:
        .word 0
        movem 1,pi5a
        movem 2,pi5b
        pushj 17,storage_pi_handler
        move 1,pi5a
        move 2,pi5b
        jrst 010,@disk_pi
clock_pi:
        .word 0
        movem 1,pi6a
        movem 2,pi6b
        movem 3,pi6c
        cono 0000,003006
        aos ticks
        pushj 17,storage_clock_tick
        move 1,pi6a
        move 2,pi6b
        move 3,pi6c
        jrst 010,@clock_pi
proc_wakeup_event:
        aos wakes
        move 1,wakes
        caie 1,1
        popj 17,
        move 1,ticks
        sub 1,started
        movem 1,first_elapsed
        ; Permit the next request's genuine PI5 interrupts. If called
        ; by the atomic watchdog, leave global PI restoration to it.
        cono 0004,002004
        popj 17,
proc_wait_event:
pdp10_pi_dispatch_done:
pdp10_pi_handler_return:
        popj 17,
        .data
req_bad: .word 0,,buf_bad
         .word 0
         .word 0
req_a:   .word 0200000,,buf_a
         .word 0
         .word 0
req_b:   .word 0200001,,buf_b
         .word 0
         .word 0
        .bss
        .globl proc_current_slot
proc_current_slot: .block 1
proc_table: .block 1
silent: .block 1
ticks: .block 1
wakes: .block 1
started: .block 1
first_elapsed: .block 1
pi3a: .block 1
pi3b: .block 1
pi5a: .block 1
pi5b: .block 1
pi6a: .block 1
pi6b: .block 1
pi6c: .block 1
buf_bad: .block 0200
buf_a: .block 0200
buf_b: .block 0200
buf_c: .block 0200
stack: .block 01000
