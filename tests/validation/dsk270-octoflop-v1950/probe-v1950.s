; H-270 (Apr 1966), pp. 2-11, 3-8, 3-11, 3-26.
; DSK0 attached; DSK1 absent. Three independent entries.
        .text
        .globl clear_test
        .globl reselect_test
        .globl dfr_test
clear_test:
        movei 1,0200000
        datao 0270,1
        pushj 17,wait_error
        cono 0270,030200
        coni 0270,2
        trnn 2,0100000
        jrst fail
        trne 2,0400000
        jrst fail
        movei 1,0
        datao 0270,1
        cono 0270,0
        pushj 17,wait_ready
        jrst pass

reselect_test:
        ; Start a long seek on the attached drive. ADT permits new DATAO.
        movei 1,07700
        datao 0270,1
        pushj 17,wait_adt
        movei 1,0200000
        datao 0270,1
        pushj 17,wait_error
        cono 0270,0200
        movei 1,0
        datao 0270,1
        pushj 17,wait_ready
        jrst pass

dfr_test:
        movei 1,0
        datao 0270,1
        pushj 17,wait_ready
        ; DFR is not an address-accepting state. Ignore this DATAO.
        movei 1,0200000
        datao 0270,1
        coni 0270,2
        trne 2,1
        jrst fail
        ; With NOP the original selection returns to ADT.
        pushj 17,wait_adt
        movei 1,0200000
        datao 0270,1
        pushj 17,wait_error
        cono 0270,0200
        movei 1,0
        datao 0270,1
        pushj 17,wait_ready
pass:
        setz 1,
        halt .
fail:
        movei 1,1
        halt .

wait_error:
        movei 3,0777777
error_loop:
        coni 0270,2
        trne 2,040000
        jrst fail
        trnn 2,0102
        jrst error_next
        trnn 2,0100000
        jrst fail
        move 4,2
        andi 4,0103
        caie 4,0103
        jrst fail
        popj 17,
error_next:
        sojg 3,error_loop
        jrst fail

wait_adt:
        movei 3,0777777
adt_loop:
        coni 0270,2
        trne 2,0100000
        popj 17,
        sojg 3,adt_loop
        jrst fail

wait_ready:
        movei 3,0777777
ready_loop:
        coni 0270,2
        trne 2,01777
        jrst fail
        trne 2,040000
        popj 17,
        sojg 3,ready_loop
        jrst fail
