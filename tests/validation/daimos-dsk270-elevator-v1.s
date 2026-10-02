        .text
        .globl main
        .globl fail_id
        .globl __test_exit
        .globl dsk_enqueue
        .globl dsk_queue
        .globl dsk_current_cyl

; Execute the production DSK270 one-way elevator selector from dsk_io.s.
; The queue packs q0 in LH and q1 in RH; each request begins raw-address,,buffer.
main:
        setzm fail_id

        ; Current 03000: an ahead request must precede one behind us.
        movei 1,03000
        movem 1,dsk_current_cyl
        setzm dsk_queue
        movei 1,req_a
        pushj 17,dsk_enqueue
        jumpn 1,fail1
        movei 1,req_b
        pushj 17,dsk_enqueue
        jumpn 1,fail2
        hlrz 2,dsk_queue
        caie 2,req_b
        jrst fail3
        hrrz 2,dsk_queue
        caie 2,req_a
        jrst fail4

        ; Both ahead: choose the nearer request.
        movei 1,01000
        movem 1,dsk_current_cyl
        setzm dsk_queue
        movei 1,req_b
        pushj 17,dsk_enqueue
        movei 1,req_c
        pushj 17,dsk_enqueue
        hlrz 2,dsk_queue
        caie 2,req_c
        jrst fail5

        ; Both behind: after wrapping, choose the lowest cylinder first.
        movei 1,05000
        movem 1,dsk_current_cyl
        setzm dsk_queue
        movei 1,req_a
        pushj 17,dsk_enqueue
        movei 1,req_c
        pushj 17,dsk_enqueue
        hlrz 2,dsk_queue
        caie 2,req_a
        jrst fail6

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
fail:   movem 1,fail_id
        popj 17,

        .data
req_a:  .word 00001017,,001000
req_b:  .word 00004043,,001000
req_c:  .word 00002025,,001000

        .bss
fail_id:     .block 1
__test_exit: .block 1
