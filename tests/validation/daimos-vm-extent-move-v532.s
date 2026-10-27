; Tests real VM and FS transfer code under native PDP-6 instruction stepping.
; This SIDL no-uarea fixture does not exercise runnable user APR/runqueue.
.text
.globl main
main:
        movei 1,7
        movem 1,proc_current_slot
        movei 1,proc_records
        movem 1,proc_table
        movei 1,010000
        movem 1,proc_records+1
        setzm proc_records
        setzm proc_records+2
        movei 1,012345
        movem 1,010000
        movei 1,076543
        movem 1,010003
        setzm 012000
        setzm 012003
        ; Reject self-relocation without touching the source or process state.
        movei 1,0
        movem 1,proc_current_slot
        movei 1,0
        movei 2,010000
        movei 3,4
        movei 4,012000
        pushj 17,vm_extent_move
        came 1,[-5]
        jrst bad1
        move 1,proc_records+1
        caie 1,010000
        jrst bad1
        movei 1,7
        movem 1,proc_current_slot
        ; Real relocation: copy four words and publish physical VM base.
        movei 1,0
        movei 2,010000
        movei 3,4
        movei 4,012000
        pushj 17,vm_extent_move
        jumpn 1,bad2
        move 1,proc_records+1
        caie 1,012000
        jrst bad3
        move 1,012000
        caie 1,012345
        jrst bad4
        move 1,012003
        caie 1,076543
        jrst bad5
        move 1,proc_records
        trne 1,0200000
        jrst bad6
        move 1,runq_calls
        jumpn 1,bad7
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
.globl proc_runq_remove
proc_runq_remove:
        aos runq_calls
        popj 17,
.globl proc_runq_add
proc_runq_add:
        aos runq_calls
        popj 17,
.bss
.globl proc_table
.globl proc_current_slot
proc_table: .block 1
proc_records: .block 6
proc_current_slot: .block 1
runq_calls: .block 1
.globl __test_exit
__test_exit: .block 1
