; Native PDP-6 extent registry shift and boundary test. Uses production insertion/deletion.
.text
.globl main
main:
        setzm mm_extent_count
        setz 010,
mm_fill:
        move 1,010
        movei 2,extent_input
        move 3,010
        movem 3,extent_input
        pushj 17,mm_extent_insert
        jumpn 1,mm_fail
        aoj 010,
        caige 010,040
        jrst mm_fill
        move 3,mm_extent_count
        caie 3,040
        jrst mm_fail
        movei 010,041
        movei 1,040
        movei 2,extent_input
        pushj 17,mm_extent_insert
        came 1,[-3]
        jrst mm_fail
        movei 010,042
        movei 1,017
        pushj 17,mm_delete
        move 3,mm_extent_count
        caie 3,037
        jrst mm_fail
        ; Insert into the middle, not just append; the tail must shift.
        movei 010,043
        movei 1,017
        movei 2,extent_input
        pushj 17,mm_extent_insert
        jumpn 1,mm_fail
        move 3,mm_extent_count
        caie 3,040
        jrst mm_fail
        move 3,mm_extents+036       ; newly inserted index 017 (two words)
        caie 3,037                 ; last input value is 037
        jrst mm_fail
        move 3,mm_extents+040       ; shifted former index 017
        caie 3,020
        jrst mm_fail
        setz 1,
        popj 17,
mm_fail:
        move 1,010
        addi 1,1
        popj 17,
.bss
.globl mm_extent_count
.globl mm_extents
mm_extent_count: .block 1
mm_extents: .block 0100
extent_input: .block 2
.globl __test_exit
__test_exit: .block 1
