; An MM descriptor may carry a slot outside the allocated process table.
; A forged record just beyond the table must never authorize VM movement.
        .text
        .globl main
main:
        movei   1,proc_records
        movem   1,proc_table
        movei   1,2
        movem   1,proc_slots
        movei   1,7
        movem   1,proc_current_slot
        ; Two live slots, 0 and 1. Slot 2 is deliberately beyond count.
        movei   1,010000
        movem   1,proc_records+7
        movei   1,012345
        movem   1,010000
        movei   1,076543
        movem   1,012000
        movei   1,2
        movei   2,010000
        movei   3,1
        movei   4,012000
        pushj   17,vm_extent_move
        came    1,[-5]
        jrst    fail_1_v1692
        move    1,proc_records+7
        caie    1,010000
        jrst    fail_2_v1692
        move    1,012000
        caie    1,076543
        jrst    fail_3_v1692
        ; The highest owner value must be refused before indexing too.
        movei   1,0377
        movei   2,010000
        movei   3,1
        movei   4,012000
        pushj   17,vm_extent_move
        came    1,[-5]
        jrst    fail_4_v1692
        ; A real slot may still relocate using the same physical words.
        movei   1,010000
        movem   1,proc_records+4
        movei   1,1
        movei   2,010000
        movei   3,1
        movei   4,012000
        pushj   17,vm_extent_move
        jumpn   1,fail_5_v1692
        move    1,proc_records+4
        caie    1,012000
        jrst    fail_6_v1692
        move    1,012000
        caie    1,012345
        jrst    fail_7_v1692
        setz    1,
        popj    17,
fail_1_v1692: movei 1,1
        popj 17,
fail_2_v1692: movei 1,2
        popj 17,
fail_3_v1692: movei 1,3
        popj 17,
fail_4_v1692: movei 1,4
        popj 17,
fail_5_v1692: movei 1,5
        popj 17,
fail_6_v1692: movei 1,6
        popj 17,
fail_7_v1692: movei 1,7
        popj 17,
        .globl proc_runq_remove
proc_runq_remove:
        popj    17,
        .globl proc_runq_add
proc_runq_add:
        popj    17,
        .bss
        .globl proc_table
        .globl proc_slots
        .globl proc_current_slot
proc_table: .block 1
proc_slots: .block 1
proc_current_slot: .block 1
proc_records: .block 011
        .globl __test_exit
__test_exit: .block 1
