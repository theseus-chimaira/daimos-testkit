; Native production VM/FS and actual scheduler intrusive runqueue routines.
.text
.globl main
main:
        movei 1,7
        movem 1,proc_current_slot
        movei 1,proc_records
        movem 1,proc_table
        move 1,[014000,,0400000] ; stable u-area at 014000
        movem 1,proc_records+3
        movei 1,010000
        movem 1,proc_records+4
        move 1,[0200000,,0] ; resident SRUN state
        movem 1,proc_records+5
        setzm 014024
        setzm proc_runq_head
        movei 1,1
        movem 1,proc_runq_head
        movei 1,012345
        movem 1,010000
        movei 1,076543
        movem 1,010003
        ; A held user mapping must prevent relocation.
        movei 1,2
        movem 1,014024
        movei 1,1
        movei 2,010000
        movei 3,4
        movei 4,012000
        pushj 17,vm_extent_move
        came 1,[-5]
        jrst bad1
        move 1,proc_records+4
        caie 1,010000
        jrst bad1
        move 1,proc_runq_head
        caie 1,1
        jrst bad1
        setzm 014024
        ; Released mapping: copy, enter STOP_MM, then resume SRUN.
        movei 1,1
        movei 2,010000
        movei 3,4
        movei 4,012000
        pushj 17,vm_extent_move
        jumpn 1,bad2
        move 1,proc_records+4
        caie 1,012000
        jrst bad3
        move 1,012000
        caie 1,012345
        jrst bad4
        move 1,012003
        caie 1,076543
        jrst bad4
        move 1,014024
        tlne 1,01000
        jrst bad5
        move 1,proc_records+5
        hlrz 2,1
        andi 2,0700000
        caie 2,0200000
        jrst bad6
        move 1,proc_runq_head
        caie 1,1
        jrst bad7
        move 1,proc_records+5
        hrrz 2,1
        jumpn 2,bad8
        setz 1,
        popj 17,
bad1:   movei 1,1
        popj 17,
bad2:   movei 1,2
        popj 17,
bad3:   movei 1,3
        popj 17,
bad4:   movei 1,4
        popj 17,
bad5:   movei 1,5
        popj 17,
bad6:   movei 1,6
        popj 17,
bad7:   movei 1,7
        popj 17,
bad8:   movei 1,010
        popj 17,
.bss
.globl proc_table
.globl proc_current_slot
proc_table: .block 1
proc_records: .block 6
proc_current_slot: .block 1
.globl proc_runq_head
proc_runq_head: .block 1
.globl __test_exit
__test_exit: .block 1
