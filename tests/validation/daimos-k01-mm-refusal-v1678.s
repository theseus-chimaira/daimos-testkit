; Native PDP-6 K01 regression for the production MM compactor.
; MM refuses a move without changing its descriptor or owner. A BUSY
; candidate must not be confused with ordinary fragmentation, but a
; second movable candidate can still satisfy the allocation.

        .text
        .globl main
main:
        movei   1,2
        movem   1,mm_extent_count
        move    1,[02000,,02000]
        movem   1,mm_extents
        move    1,[01,,01]
        movem   1,mm_extents+1
        move    1,[02000,,04000]
        movem   1,mm_extents+2
        move    1,[01,,02]
        movem   1,mm_extents+3

        ; Case 1: two refused moves => exact MM_ERR_BUSY, two attempts.
        movei   1,1
        pushj   17,run_case
        came    1,[-5]
        jrst    fail_1
        move    1,move_calls
        caie    1,2
        jrst    fail_2

        ; Case 2: first move BUSY; next candidate moves and makes space.
        movei   1,2
        pushj   17,run_case
        jumpn   1,fail_3
        move    1,move_calls
        caie    1,2
        jrst    fail_4

        ; Case 3: corrupt owner/invalid MM move => immediate -4.
        movei   1,3
        pushj   17,run_case
        came    1,[-4]
        jrst    fail_5
        move    1,move_calls
        caie    1,1
        jrst    fail_6

        ; Case 4: no candidate can relocate, no hard refusal => -2.
        movei   1,4
        pushj   17,run_case
        came    1,[-2]
        jrst    fail_7
        move    1,move_calls
        caie    1,2
        jrst    fail_8

        ; Case 5: not enough total free words => -1 before moving.
        movei   1,5
        pushj   17,run_case
        came    1,[-1]
        jrst    fail_9
        skipn   move_calls
        jrst    check_ownership
        jrst    fail_10

check_ownership:
        ; No test mock changes the production extent table.
        move    1,mm_extents
        came    1,[02000,,02000]
        jrst    fail_11
        move    1,mm_extents+1
        came    1,[01,,01]
        jrst    fail_11
        move    1,mm_extents+2
        came    1,[02000,,04000]
        jrst    fail_11
        move    1,mm_extents+3
        came    1,[01,,02]
        jrst    fail_11
        setz    1,
        popj    17,

run_case:
        movem   1,test_mode
        setzm   move_calls
        setzm   move_succeeded
        movei   1,04000
        movei   2,02000
        pushj   17,mm_compact
        popj    17,

fail_1: movei   1,1
        popj    17,
fail_2: movei   1,2
        popj    17,
fail_3: movei   1,3
        popj    17,
fail_4: movei   1,4
        popj    17,
fail_5: movei   1,5
        popj    17,
fail_6: movei   1,6
        popj    17,
fail_7: movei   1,7
        popj    17,
fail_8: movei   1,010
        popj    17,
fail_9: movei   1,011
        popj    17,
fail_10: movei  1,012
        popj    17,
fail_11: movei  1,013
        popj    17,

; The real compactor calls these two private leaves; the test changes
; only the outcome of the requested move and free-space observation.
        .globl mm_find_fit
mm_find_fit:
        movei   5,05000
        move    3,test_mode
        caie    3,5
        jrst    fit_words
        movei   5,01000
fit_words:
        movem   5,(4)
        skipn   move_succeeded
        jrst    no_fit
        movei   1,1
        popj    17,
no_fit:
        setz    1,
        popj    17,

        .globl mm_move_extent
mm_move_extent:
        aos     move_calls
        move    3,test_mode
        caie    3,2
        jrst    move_other
        jumpe   1,move_busy
        movei   4,1
        movem   4,move_succeeded
        setz    1,
        popj    17,
move_other:
        caie    3,3
        jrst    move_other_2
        movni   1,4
        popj    17,
move_other_2:
        caie    3,4
        jrst    move_busy
        movni   1,2
        popj    17,
move_busy:
        movni   1,5
        popj    17,

        .bss
        .globl mm_extents
        .globl mm_extent_count
mm_extents:      .block 4
mm_extent_count: .block 1
test_mode:       .block 1
move_calls:      .block 1
move_succeeded:  .block 1
        .globl __test_exit
__test_exit:     .block 1
