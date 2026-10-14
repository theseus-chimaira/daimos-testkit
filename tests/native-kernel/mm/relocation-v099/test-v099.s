/* PDP-6 MM compaction exercises real mm_move_extent descriptor lifecycle. */
.text
.globl main
main:
        pushj 17,setup
        ; Largest free island=04000, sum=06000; moving process uphill
        ; should produce a contiguous region large enough for 05000.
        movei 1,05000
        movei 2,1
        pushj 17,mm_compact
        jumpn 1,fail_1
        move 1,pi_disabled
        caie 1,1
        jrst fail_2
        move 1,pi_restored
        caie 1,1
        jrst fail_3
        move 1,moved_owner
        caie 1,7
        jrst fail_4
        move 1,moved_source
        caie 1,024000
        jrst fail_5
        move 1,moved_dest
        caie 1,026000
        jrst fail_6
        hrrz 1,mm_extents
        caie 1,026000
        jrst fail_7
        move 1,mm_extent_count
        caie 1,2
        jrst fail_8
        ; Rejected VM relocation must leave the original extent intact.
        pushj 17,setup
        movei 1,5
        movem 1,move_result
        movei 1,05000
        movei 2,1
        pushj 17,mm_compact
        came 1,[-2]
        jrst fail_9
        hrrz 1,mm_extents
        caie 1,024000
        jrst fail_10
        move 1,mm_extent_count
        caie 1,2
        jrst fail_11
        move 1,pi_disabled
        caie 1,1
        jrst fail_12
        move 1,pi_restored
        caie 1,1
        jrst fail_13
        setz 1,
        popj 17,
setup:
        setzm move_result
        setzm moved_owner
        setzm moved_source
        setzm moved_dest
        setzm pi_disabled
        setzm pi_restored
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
fail_10: movei 1,12
        popj 17,
fail_11: movei 1,13
        popj 17,
fail_12: movei 1,14
        popj 17,
fail_13: movei 1,15
        popj 17,
.bss
.globl __test_exit
__test_exit: .block 1
