/* Execute production MM + extracted, byte-for-byte VM relocation logic. */
.text
.globl main
main:
        movei 1,04000
        movem 1,proc_table
        setzm proc_current_slot
        setzm pi_disabled
        setzm pi_restored
        setzm runq_added
        setzm runq_removed
        movei 1,1
        movem 1,mm_arena_count
        move 1,[010000,,020000]
        movem 1,mm_arenas
        movei 1,0100000
        movem 1,mm_core_words
        movei 1,2
        movem 1,mm_extent_count
        move 1,[01000,,024000]
        movem 1,mm_extents
        move 1,[1,,7]
        movem 1,mm_extents+1
        move 1,[03000,,027000]
        movem 1,mm_extents+2
        move 1,[2,,3]
        movem 1,mm_extents+3
        move 1,[0300000,,0]
        movem 1,04025
        movei 1,024000
        movem 1,04026
        move 1,[012345670123]
        movem 1,024000
        move 1,[076543210765]
        movem 1,024777
        movei 1,05000
        movei 2,1
        pushj 17,mm_compact
        jumpn 1,fail_1
        hrrz 1,mm_extents
        caie 1,026000
        jrst fail_2
        hrrz 1,04026
        caie 1,026000
        jrst fail_3
        move 1,026000
        came 1,[012345670123]
        jrst fail_4
        move 1,026777
        came 1,[076543210765]
        jrst fail_5
        move 1,pi_disabled
        caie 1,1
        jrst fail_6
        move 1,pi_restored
        caie 1,1
        jrst fail_7
        ; Reject the currently running process before changing data.
        movei 1,7
        movem 1,proc_current_slot
        move 1,[076543210765]
        movem 1,026000
        movei 1,7
        movei 2,026000
        movei 3,01000
        movei 4,030000
        pushj 17,vm_extent_move
        came 1,[-5]
        jrst fail_8
        move 1,026000
        came 1,[076543210765]
        jrst fail_9
        ; Non-current process with transition flag must also be rejected.
        setzm proc_current_slot
        move 1,[0300000,,0200000]
        movem 1,04025
        movei 1,7
        movei 2,026000
        movei 3,01000
        movei 4,030000
        pushj 17,vm_extent_move
        came 1,[-5]
        jrst fail_10
        move 1,026000
        came 1,[076543210765]
        jrst fail_11
        setz 1,
        popj 17,
fail_1: movei 1,1
        popj 17,
fail_2: movei 1,2
        popj 17,
fail_3: movei 1,3
        popj 17,
fail_4: movei 1,4
        popj 17,
fail_5: movei 1,5
        popj 17,
fail_6: movei 1,6
        popj 17,
fail_7: movei 1,7
        popj 17,
fail_8: movei 1,10
        popj 17,
fail_9: movei 1,11
        popj 17,
fail_10: movei 1,012
        popj 17,
fail_11: movei 1,013
        popj 17,
.bss
.globl __test_exit
__test_exit: .block 1
