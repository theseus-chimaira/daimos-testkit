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
        ; Fill every source word, so relocation checks the full payload.
        setz 6,
fill_payload:
        move 1,6
        xor 1,[012345670123]
        movem 1,024000(6)
        aoj 6,
        caige 6,01000
        jrst fill_payload
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
        ; Verify all 01000 copied words with an independent pattern oracle.
        setz 6,
verify_payload:
        move 1,6
        xor 1,[012345670123]
        came 1,026000(6)
        jrst fail_4
        aoj 6,
        caige 6,01000
        jrst verify_payload
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
        ; Direct VM relocation must reject unaligned destination.
        setzm 04025
        movei 1,7
        movei 2,026000
        movei 3,01000
        movei 4,030001
        pushj 17,vm_extent_move
        came 1,[-5]
        jrst fail_12
        ; Set the mapping-held bit in a stable u-area, reject before copy.
        move 1,[0300000,,0400000]
        movem 1,04025
        movei 1,05000
        hrlm 1,04025
        movei 1,2
        movem 1,05024
        movei 1,7
        movei 2,026000
        movei 3,01000
        movei 4,030000
        pushj 17,vm_extent_move
        came 1,[-5]
        jrst fail_13
        move 1,026000
        came 1,[076543210765]
        jrst fail_14
        ; Exercise stable u-area stop and runnable-queue restoration.
        move 1,[0300000,,0400000]
        movem 1,04025
        movei 1,05000
        hrlm 1,04025
        setzm 05024
        move 1,[0200000,,0]
        movem 1,04027
        setzm runq_removed
        setzm runq_added
        movei 1,7
        movei 2,026000
        movei 3,01000
        movei 4,030000
        pushj 17,vm_extent_move
        jumpn 1,fail_15
        move 1,runq_removed
        caie 1,1
        jrst fail_16
        move 1,runq_added
        caie 1,1
        jrst fail_17
        hrrz 1,04026
        caie 1,030000
        jrst fail_18
        move 1,05024
        tlne 1,01000
        jrst fail_19
        ; A pinned process must not be selected by compaction.
        movei 1,2
        movem 1,mm_extent_count
        move 1,[01000,,024000]
        movem 1,mm_extents
        move 1,[011,,7]
        movem 1,mm_extents+1
        move 1,[03000,,027000]
        movem 1,mm_extents+2
        move 1,[2,,3]
        movem 1,mm_extents+3
        setzm pi_disabled
        setzm pi_restored
        movei 1,05000
        movei 2,1
        pushj 17,mm_compact
        came 1,[-2]
        jrst fail_20
        hrrz 1,mm_extents
        caie 1,024000
        jrst fail_21
        skipn pi_disabled
        jrst pin_pi_ok
        jrst fail_22
pin_pi_ok:
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
fail_12: movei 1,014
        popj 17,
fail_13: movei 1,015
        popj 17,
fail_14: movei 1,016
        popj 17,
fail_15: movei 1,017
        popj 17,
fail_16: movei 1,020
        popj 17,
fail_17: movei 1,021
        popj 17,
fail_18: movei 1,022
        popj 17,
fail_19: movei 1,023
        popj 17,
fail_20: movei 1,024
        popj 17,
fail_21: movei 1,025
        popj 17,
fail_22: movei 1,026
        popj 17,
.bss
.globl __test_exit
__test_exit: .block 1
