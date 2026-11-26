; Native source-linked shared PI2 test. No production state deposits.
; Real DCS/RM10 handlers; test-only process event stubs.
        .text
        .globl start
        .globl ready
        .globl issued
        .globl passed
        .globl failed
        .globl pi2
        .globl received
        .globl buffer
        .globl request
        .globl overlap
        .globl rx_first
        .globl mode
        .globl dma_first
        .globl rx_count
        .globl wakes
        .globl proc_table
        .globl proc_wakeup_event
        .globl proc_wait_event
        .globl proc_wait_event_intr
        .globl proc_tty_pending_take
        .globl proc_tty_pending_store
        .globl pdp10_pi_dispatch_done
        .globl pdp10_pi_handler_return
start:
        move 17,[-01000,,stack-1]
        setom proc_table
        move 1,[jsr pi2]
        movem 1,044
        cono 4,010000
        ; Leave PI off until both hardware conditions can coexist.
        cono 4,002040
        cono 0300,012
ready:
        halt .
        move 1,mode
        caie 1,2
        jrst await_rx
        jrst start_dma
        ; Poll genuine hardware only.
await_rx:
        coni 0300,1
        andi 1,017
        caie 1,012
        jrst await_rx
        ; Real pending DCS receive, before starting native DMA.
start_dma:
        movei 1,request
        pushj 17,rm10_start_v1970
        move 1,mode
        caie 1,1
        jrst issued
await_done:
        conso 0170,010
        jrst await_done
issued:
        cono 4,000200
        ; Wait for both real device completions.
await_both:
        skipn rx_count
        jrst await_both
        skipn received
        pushj 17,rx_consume
        skipe request+2
        skipn received
        jrst await_both
        move 1,request+2
        caie 1,1
        jrst failed
        move 1,received
        caie 1,0132
        jrst failed
passed:
        halt .
failed:
        halt .
pi2:
        .word 0
        movem 1,save1
        movem 2,save2
        movem 3,save3
        pushj 17,dcs_pi_handler
        move 1,save1
        move 2,save2
        move 3,save3
        jrst 012,@pi2
; Test link patches the actual DCS tail exactly like MINIT.
pdp10_pi_handler_return:
pdp10_pi_dispatch_done:
        popj 17,
proc_wakeup_event:
        aos wakes
        caie 1,request+2
        jrst rx_wake
        skipe rx_count
        popj 17,
        aos dma_first
        popj 17,
rx_wake:
        aos rx_count
        skipn drm236_active_request
        jrst rx_done
        aos overlap
        coni 0170,2
        trne 2,020
        aos rx_first
rx_done:
        popj 17,
proc_tty_pending_take:
        seto 1,
        popj 17,
proc_tty_pending_store:
proc_wait_event_intr:
proc_wait_event:
        jrst failed
        .globl rx_consume
rx_consume:
        setz 1,
        pushj 17,dcs_getchar
        movem 1,received
        popj 17,
        .data
mode:   .word 0
request: .word 0,,buffer
        .word 0
        .word 0
        .bss
proc_table: .block 1
received: .block 1
rx_count: .block 1
dma_first: .block 1
overlap: .block 1
rx_first: .block 1
wakes: .block 1
save1: .block 1
save2: .block 1
save3: .block 1
guard_before: .block 1
buffer: .block 0200
guard_after: .block 1
stack: .block 01000
