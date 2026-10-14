/* PDP-6 native MM allocator smoke and ownership test, no kernel boot. */
.text
.globl main
main:
        movei 1,1
        movem 1,mm_arena_count
        move 1,[04000,,020000]
        movem 1,mm_arenas
        movei 1,0100000
        movem 1,mm_core_words
        setzm mm_extent_count
        ; allocate low aligned 01000 words
        movei 1,01000
        movei 2,2
        movei 3,1
        setz 4,
        movei 5,first_base
        push 17,5
        pushj 17,mm_alloc
        sub 17,[1,,1]
        jumpn 1,fail_1
        move 1,first_base
        caie 1,020000
        jrst fail_2
        ; allocate high aligned 01000 words
        movei 1,01000
        movei 2,2
        movei 3,2
        movei 4,1
        movei 5,last_base
        push 17,5
        pushj 17,mm_alloc
        sub 17,[1,,1]
        jumpn 1,fail_3
        move 1,last_base
        caie 1,023000
        jrst fail_4
        ; a pin prevents freeing; ownership must be correct.
        move 1,first_base
        pushj 17,mm_pin
        jumpn 1,fail_5
        move 1,first_base
        movei 2,2
        movei 3,1
        pushj 17,mm_free
        came 1,[-5]
        jrst fail_6
        move 1,first_base
        pushj 17,mm_unpin
        jumpn 1,fail_7
        move 1,first_base
        movei 2,2
        movei 3,2
        pushj 17,mm_free
        came 1,[-4]
        jrst fail_8
        move 1,first_base
        movei 2,2
        movei 3,1
        pushj 17,mm_free
        jumpn 1,fail_9
        ; the deleted gap must immediately be available again.
        movei 1,01000
        movei 2,2
        movei 3,3
        setz 4,
        movei 5,reused_base
        push 17,5
        pushj 17,mm_alloc
        sub 17,[1,,1]
        jumpn 1,fail_10
        move 1,reused_base
        caie 1,020000
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
fail_8: movei 1,010
        popj 17,
fail_9: movei 1,011
        popj 17,
fail_10: movei 1,012
        popj 17,
fail_11: movei 1,013
        popj 17,
.bss
first_base: .block 1
last_base: .block 1
reused_base: .block 1
.globl __test_exit
__test_exit: .block 1
