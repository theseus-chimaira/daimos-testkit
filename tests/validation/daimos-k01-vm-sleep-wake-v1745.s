; Exercise sleeping VM owner across real extracted vm_extent_move.
        .text
        .globl main
main:
        cono    0004,02026            ; enable disk PI3/PI5 and scheduler PI6
        cono    0004,000200           ; keep global priority interrupts on
        movei   1,proc_records_v1745
        movem   1,proc_table
        movei   1,2
        movem   1,proc_slots
        movei   1,7
        movem   1,proc_current_slot
        ; Original SLEEP has an event wait channel, with a live u-area.
        move    1,[uarea_v1745,,0400000]
        movem   1,proc_records_v1745
        move    1,[02000,,010000]
        movem   1,proc_records_v1745+1
        move    1,[0320000,,event_v1745]
        movem   1,proc_records_v1745+2
        setzm   uarea_v1745+024
        setzm   inject_v1745
        pushj   17,do_move_v1745
        jumpn   1,fail1_v1745
        hlrz    1,proc_records_v1745+2
        andi    1,0700000
        caie    1,0300000          ; must remain SLEEP without wake
        jrst    fail2_v1745
        hrrz    1,proc_records_v1745+2
        caie    1,event_v1745
        jrst    fail3_v1745
        ; Repeat and inject a DSK PI5 wakeup inside the actual copy.
        move    1,[02000,,010000]
        movem   1,proc_records_v1745+1
        move    1,[0320000,,event_v1745]
        movem   1,proc_records_v1745+2
        setom   inject_v1745
        pushj   17,do_move_v1745
        jumpn   1,fail4_v1745
        hlrz    1,proc_records_v1745+2
        andi    1,0700000
        caie    1,0200000          ; wake must be delivered as RUN
        jrst    fail5_v1745
        hrrz    1,proc_records_v1745+2
        jumpn   1,fail6_v1745
        move    1,enqueues_v1745
        caie    1,1
        jrst    fail7_v1745
        skipn   pi_contract_bad_v1745
        jrst    check_restored_v1745
        jrst    fail8_v1745
check_restored_v1745:
        coni    0004,7
        trnn    7,000004              ; PI5 must be restored on return
        jrst    fail9_v1745
        setz    1,
        popj    17,
do_move_v1745:
        movei   1,0
        movei   2,010000
        movei   3,02000
        movei   4,012000
        pushj   17,vm_extent_move
        popj    17,
fail1_v1745: movei 1,1
        popj 17,
fail2_v1745: movei 1,2
        popj 17,
fail3_v1745: movei 1,3
        popj 17,
fail4_v1745: movei 1,4
        popj 17,
fail5_v1745: movei 1,5
        popj 17,
fail6_v1745: movei 1,6
        popj 17,
fail7_v1745: movei 1,7
        popj 17,
fail8_v1745: movei 1,010
        popj 17,
fail9_v1745: movei 1,011
        popj 17,
        .globl fs_move_words
fs_move_words:
        coni    0004,7
        trnn    7,000004              ; PI5 available throughout copying
        aos     pi_contract_bad_v1745
        trnn    7,000020              ; PI3 must remain available too
        aos     pi_contract_bad_v1745
        skipn   inject_v1745
        popj    17,
        setzm   inject_v1745
        ; PI5 completion: proc_wakeup_event clears wait and SLEEP,
        ; but cannot change the temporary STOP state to RUN.
        move    2,proc_records_v1745+2
        tlz     2,060000
        hllz    2,2
        tlz     2,0100000
        movem   2,proc_records_v1745+2
        popj    17,
        .globl proc_runq_remove
proc_runq_remove:
        coni    0004,7
        trne    7,000004              ; PI5 inhibited during state change
        aos     pi_contract_bad_v1745
        popj    17,
        .globl proc_runq_add
proc_runq_add:
        coni    0004,7
        trne    7,000004              ; also inhibit PI5 at commit
        aos     pi_contract_bad_v1745
        aos     enqueues_v1745
        popj    17,
        .bss
        .globl proc_table
        .globl proc_current_slot
        .globl proc_slots
proc_table: .block 1
proc_slots: .block 1
proc_current_slot: .block 1
proc_records_v1745: .block 6
uarea_v1745: .block 050
inject_v1745: .block 1
enqueues_v1745: .block 1
event_v1745: .block 1
pi_contract_bad_v1745: .block 1
        .globl __test_exit
__test_exit: .block 1
