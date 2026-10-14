/* Native PDP-6 bounded reclaim policy and failure atomicity. */
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
        setzm fs_calls
        setzm swap_calls
        movei 1,077777
        movem 1,chosen
        ; Request more than the entire arena, retry must be bounded.
        movei 1,05000
        movei 2,1
        movei 3,2
        movei 4,7
        movei 5,chosen
        push 17,5
        push 17,[0]
        pushj 17,mm_alloc_aligned
        sub 17,[2,,2]
        came 1,[-1]
        jrst fail_1
        move 1,fs_calls
        caie 1,2
        jrst fail_2
        move 1,swap_calls
        caie 1,1
        jrst fail_3
        move 1,chosen
        caie 1,077777
        jrst fail_4
        skipn mm_extent_count
        jrst first_good
        jrst fail_5
first_good:
        ; Critical no-reclaim variant must never invoke callbacks.
        setzm fs_calls
        setzm swap_calls
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
        jrst fail_6
        skipn fs_calls
        jrst fs_good
        jrst fail_7
fs_good:
        skipn swap_calls
        jrst swap_good
        jrst fail_8
swap_good:
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
.bss
chosen: .block 1
.globl __test_exit
__test_exit: .block 1
