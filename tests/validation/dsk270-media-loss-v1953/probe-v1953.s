; Type 270: physical host detach during address acquisition.
; Monitor stops at linked instruction boundaries, not status deposits.
        .text
        .globl sna_start
        .globl sna_loss
        .globl adt_start
        .globl adt_loss
        .globl recovery
        .globl early_start
        .globl early_loss
        .globl peer_start
        .globl peer_loss
sna_start:
        movei 1,0
        datao 0270,1
sna_loss:
        coni 0270,2
        trne 2,040000
        jrst fail
        trnn 2,0200000
        jrst fail
        jrst wait_error
adt_start:
        movei 1,07700
        datao 0270,1
        movei 3,0777777
adt_loop:
        coni 0270,2
        trne 2,0100000
        jrst adt_loss
        sojg 3,adt_loop
        jrst fail
adt_loss:
        coni 0270,2
        trnn 2,0100000
        jrst fail
        jrst wait_error
early_start:
        movei 1,0
        datao 0270,1
early_loss:
        ; The monitor detached and immediately reattached DSK0.
        ; The old acquisition must terminate as an error, not DFR.
        movei 3,0777777
early_loop:
        coni 0270,2
        trne 2,040000
        jrst fail
        move 4,2
        andi 4,0103
        caie 4,0102
        jrst early_next
        trne 2,0100000
        jrst pass
early_next:
        sojg 3,early_loop
        jrst fail
peer_start:
        movei 1,0
        datao 0270,1
peer_loss:
        ; Detach a different unit during selected DSK0 SNA.
        ; No error from the unselected unit and no canceled event.
        jrst ready_init
wait_error:
        movei 3,0777777
error_loop:
        coni 0270,2
        trne 2,040000
        jrst fail
        move 4,2
        andi 4,0103
        caie 4,0103
        jrst error_next
        trnn 2,0100000
        jrst error_next
        setz 1,
        halt .
error_next:
        sojg 3,error_loop
        jrst fail
recovery:
        ; Reattached same unit; clear status, legal DATAO in ADT.
        cono 0270,0200
        movei 1,0
        datao 0270,1
ready_init:
        movei 3,0777777
ready_loop:
        coni 0270,2
        trne 2,01777
        jrst fail
        trne 2,040000
        jrst pass
        sojg 3,ready_loop
        jrst fail
pass:
        setz 1,
        halt .
fail:
        movei 1,1
        halt .
