/* Production mm_pdp6.s: deletion, sorted descriptors, gap reuse, errors. */
.text
.globl main
main:
        setzm mm_extent_count
        movei 1,1
        movem 1,mm_arena_count
        move 1,[06000,,020000]
        movem 1,mm_arenas
        movei 1,0100000
        movem 1,mm_core_words
        ; Three distinct owner-typed extents in ascending memory order.
        movei 1,01000
        movei 2,2
        movei 3,1
        setz 4,
        movei 5,base_a
        push 17,5
        pushj 17,mm_alloc
        sub 17,[1,,1]
        jumpn 1,bad_1
        movei 1,01000
        movei 2,2
        movei 3,2
        setz 4,
        movei 5,base_b
        push 17,5
        pushj 17,mm_alloc
        sub 17,[1,,1]
        jumpn 1,bad_2
        movei 1,01000
        movei 2,2
        movei 3,3
        setz 4,
        movei 5,base_c
        push 17,5
        pushj 17,mm_alloc
        sub 17,[1,,1]
        jumpn 1,bad_3
        move 1,mm_extent_count
        caie 1,3
        jrst bad_4
        move 1,base_a
        caie 1,020000
        jrst bad_5
        move 1,base_b
        caie 1,021000
        jrst bad_6
        move 1,base_c
        caie 1,022000
        jrst bad_7
        ; Ownership rejection cannot alter descriptor count.
        move 1,base_b
        movei 2,2
        movei 3,7
        pushj 17,mm_free
        came 1,[-4]
        jrst bad_8
        move 1,mm_extent_count
        caie 1,3
        jrst bad_9
        ; Delete middle entry: later descriptor must shift down.
        move 1,base_b
        movei 2,2
        movei 3,2
        pushj 17,mm_free
        jumpn 1,bad_10
        move 1,mm_extent_count
        caie 1,2
        jrst bad_11
        hrrz 1,mm_extents+2
        caie 1,022000
        jrst bad_12
        ; A second free must reject the no-longer-existing base.
        move 1,base_b
        movei 2,2
        movei 3,2
        pushj 17,mm_free
        came 1,[-4]
        jrst bad_13
        ; Refill the hole; insertion must preserve address ordering.
        movei 1,01000
        movei 2,2
        movei 3,4
        setz 4,
        movei 5,base_reuse
        push 17,5
        pushj 17,mm_alloc
        sub 17,[1,,1]
        jumpn 1,bad_14
        move 1,base_reuse
        caie 1,021000
        jrst bad_15
        hrrz 1,mm_extents+2
        caie 1,021000
        jrst bad_16
        hrrz 1,mm_extents+4
        caie 1,022000
        jrst bad_17
        ; Remove first, then last: no stale descriptor can remain.
        move 1,base_a
        movei 2,2
        movei 3,1
        pushj 17,mm_free
        jumpn 1,bad_18
        move 1,base_c
        movei 2,2
        movei 3,3
        pushj 17,mm_free
        jumpn 1,bad_19
        move 1,mm_extent_count
        caie 1,1
        jrst bad_20
        hrrz 1,mm_extents
        caie 1,021000
        jrst bad_21
        setz 1,
        popj 17,
bad_1: movei 1,1
        popj 17,
bad_2: movei 1,2
        popj 17,
bad_3: movei 1,3
        popj 17,
bad_4: movei 1,4
        popj 17,
bad_5: movei 1,5
        popj 17,
bad_6: movei 1,6
        popj 17,
bad_7: movei 1,7
        popj 17,
bad_8: movei 1,10
        popj 17,
bad_9: movei 1,11
        popj 17,
bad_10: movei 1,12
        popj 17,
bad_11: movei 1,13
        popj 17,
bad_12: movei 1,14
        popj 17,
bad_13: movei 1,15
        popj 17,
bad_14: movei 1,16
        popj 17,
bad_15: movei 1,17
        popj 17,
bad_16: movei 1,20
        popj 17,
bad_17: movei 1,21
        popj 17,
bad_18: movei 1,22
        popj 17,
bad_19: movei 1,23
        popj 17,
bad_20: movei 1,24
        popj 17,
bad_21: movei 1,25
        popj 17,
.bss
base_a: .block 1
base_b: .block 1
base_c: .block 1
base_reuse: .block 1
.globl __test_exit
__test_exit: .block 1
