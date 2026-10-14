/* Native production MM gap scanner: two arenas and four occupied islands.
 * Unrelated dependency callbacks are isolated, MM algorithm is not mocked.
 */
.text
.globl main
main:
        movei 1,2
        movem 1,mm_arena_count
        move 1,[04000,,020000]
        movem 1,mm_arenas
        move 1,[04000,,030000]
        movem 1,mm_arenas+1
        movei 1,0100000
        movem 1,mm_core_words
        pushj 17,setup
        ; First interior hole: LOW must select the first candidate.
        movei 1,0400
        movei 2,0200
        movei 3,2
        movei 4,7
        movei 5,chosen
        push 17,5
        push 17,[0]
        pushj 17,mm_alloc_aligned_noreclaim
        sub 17,[2,,2]
        jumpn 1,fail_1
        move 1,chosen
        caie 1,021000
        jrst fail_2
        pushj 17,setup
        ; HIGH must choose the final tail gap in arena two.
        movei 1,0400
        movei 2,0200
        movei 3,2
        movei 4,7
        movei 5,chosen
        push 17,5
        push 17,[1]
        pushj 17,mm_alloc_aligned_noreclaim
        sub 17,[2,,2]
        jumpn 1,fail_3
        move 1,chosen
        caie 1,033400
        jrst fail_4
        pushj 17,setup
        ; 02000 alignment forbids all four 01000-word holes.
        movei 1,0400
        movei 2,02000
        movei 3,2
        movei 4,7
        movei 5,chosen
        push 17,5
        push 17,[0]
        pushj 17,mm_alloc_aligned_noreclaim
        sub 17,[2,,2]
        came 1,[-2]
        jrst fail_5
        ; Failed request must not change extent count or output base.
        move 1,mm_extent_count
        caie 1,4
        jrst fail_6
        pushj 17,setup
        ; Unaligned request larger than any hole, but <= total free.
        movei 1,02000
        movei 2,1
        movei 3,2
        movei 4,7
        movei 5,chosen
        push 17,5
        push 17,[1]
        pushj 17,mm_alloc_aligned_noreclaim
        sub 17,[2,,2]
        came 1,[-2]
        jrst fail_7
        pushj 17,setup
        ; Larger than aggregate free is NOMEM, not FRAGMENTED.
        movei 1,05000
        movei 2,1
        movei 3,2
        movei 4,7
        movei 5,chosen
        push 17,5
        push 17,[0]
        pushj 17,mm_alloc_aligned_noreclaim
        sub 17,[2,,2]
        came 1,[-1]
        jrst fail_8
        ; Invalid zero request is rejected without descriptor mutation.
        pushj 17,setup
        setz 1,
        movei 2,1
        movei 3,2
        movei 4,7
        movei 5,chosen
        push 17,5
        push 17,[0]
        pushj 17,mm_alloc_aligned_noreclaim
        sub 17,[2,,2]
        came 1,[-4]
        jrst fail_9
        move 1,mm_extent_count
        caie 1,4
        jrst fail_10
        ; A non-power-of-two alignment is invalid.
        movei 1,0400
        movei 2,3
        movei 3,2
        movei 4,7
        movei 5,chosen
        push 17,5
        push 17,[0]
        pushj 17,mm_alloc_aligned_noreclaim
        sub 17,[2,,2]
        came 1,[-4]
        jrst fail_11
        ; Exhaust descriptor capacity without filling physical memory.
        movei 1,040
        movem 1,mm_extent_count
        movei 1,0400
        movei 2,1
        movei 3,2
        movei 4,7
        movei 5,chosen
        push 17,5
        push 17,[0]
        pushj 17,mm_alloc_aligned_noreclaim
        sub 17,[2,,2]
        came 1,[-3]
        jrst fail_12
        move 1,mm_extent_count
        caie 1,040
        jrst fail_13
        setz 1,
        popj 17,
setup:
        movei 1,4
        movem 1,mm_extent_count
        move 1,[01000,,020000]
        movem 1,mm_extents
        move 1,[2,,1]
        movem 1,mm_extents+1
        move 1,[01000,,022000]
        movem 1,mm_extents+2
        move 1,[2,,2]
        movem 1,mm_extents+3
        move 1,[01000,,030000]
        movem 1,mm_extents+4
        move 1,[2,,3]
        movem 1,mm_extents+5
        move 1,[01000,,032000]
        movem 1,mm_extents+6
        move 1,[2,,4]
        movem 1,mm_extents+7
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
chosen: .block 1
.globl __test_exit
__test_exit: .block 1
