; Native Type-270 selected-medium loss after DFR and during SCS.
; The monitor removes the disk at linked execution breakpoints.
        .text
        .globl read_start
        .globl ready_loss
        .globl read_loss
        .globl write_start
        .globl write_loss
        .globl recovery
        .globl ready_check
read_start:
        movei 1,0
        datao 0270,1
        movei 3,0777777
ready_loop:
        coni 0270,2
        trne 2,040000
        jrst ready_loss
        sojg 3,ready_loop
        jrst fail
ready_loss:
        cono 0270,01000
        movei 3,0777777
read_loop:
        coni 0270,2
        trne 2,004000
        jrst read_loss
        sojg 3,read_loop
        jrst fail
read_loss:
        ; Missing medium must report FER and remain SCS until END.
        coni 0270,2
        trnn 2,2
        jrst fail
        trnn 2,004000
        jrst fail
        cono 0270,030200
        movei 3,0777777
idle_loop:
        coni 0270,2
        trne 2,0400000
        jrst pass
        sojg 3,idle_loop
        jrst fail
ready_check:
        ; DFR loss: no fake IDS, NOP lets DFR return to ADT.
        coni 0270,2
        trnn 2,2
        jrst fail
        cono 0270,0
        movei 3,0777777
adt_loop:
        coni 0270,2
        trne 2,0100000
        jrst pass
        sojg 3,adt_loop
        jrst fail
write_start:
        movei 1,0
        datao 0270,1
        movei 3,0777777
write_ready:
        coni 0270,2
        trne 2,040000
        jrst write_cmd
        sojg 3,write_ready
        jrst fail
write_cmd:
        cono 0270,02000
        movei 3,0777777
write_loop:
        coni 0270,2
        trne 2,004000
        jrst write_loss
        sojg 3,write_loop
        jrst fail
write_loss:
        ; WRITE cannot invent end-of-sector clocks after removal.
        ; Even if a different file has appeared, no old write may
        ; complete or modify it. END alone cannot terminate WRITE.
        coni 0270,2
        trnn 2,2
        jrst fail
        cono 0270,030200
        movei 3,02000
write_hold:
        coni 0270,2
        trnn 2,004000
        jrst fail
        sojg 3,write_hold
        jrst pass
recovery:
        cono 0270,0200
        movei 1,0
        datao 0270,1
        movei 3,0777777
recover_loop:
        coni 0270,2
        trne 2,01777
        jrst fail
        trne 2,040000
        jrst pass
        sojg 3,recover_loop
        jrst fail
pass:
        setz 1,
        halt .
fail:
        movei 1,1
        halt .
