; PDP-6 native descriptor saturation, guard and recovery fixture.
; Production mm_extent_insert and mm_delete are linked by runner.
        .text
        .globl main
main:
        setzm mm_extent_count
        setz 010,
fill:
        move 1,010
        movei 2,source
        move 3,010
        movem 3,source
        pushj 17,mm_extent_insert
        jumpn 1,fail
        aoj 010,
        caige 010,0204                ; 132: measured 256K high-water
        jrst fill
        move 3,mm_extent_count
        caie 3,0204
        jrst fail
        ; The remaining four allocations must fit, reaching exactly 136.
more:
        move 1,010
        movei 2,source
        move 3,010
        movem 3,source
        pushj 17,mm_extent_insert
        jumpn 1,fail
        aoj 010,
        caige 010,0210
        jrst more
        move 3,mm_extent_count
        caie 3,0210
        jrst fail
        ; The 137th allocation must fail without changing the registry.
        movei 1,0210
        movei 2,source
        pushj 17,mm_extent_insert
        came 1,[-3]
        jrst fail
        move 3,mm_extent_count
        caie 3,0210
        jrst fail
        ; Reclaim one middle descriptor, then insert at its old position.
        movei 1,0100
        pushj 17,mm_delete
        move 3,mm_extent_count
        caie 3,0207
        jrst fail
        movei 1,0100
        movei 2,source
        movei 3,0777
        movem 3,source
        pushj 17,mm_extent_insert
        jumpn 1,fail
        move 3,mm_extent_count
        caie 3,0210
        jrst fail
        move 3,mm_extents+0200       ; index 0100, 2 words per entry
        caie 3,0777
        jrst fail
        setz 1,
        popj 17,
fail:
        movei 1,1
        popj 17,
        .bss
        .globl mm_extent_count
        .globl mm_extents
mm_extent_count: .block 1
mm_extents: .block 0420
source: .block 2
        .globl __test_exit
__test_exit: .block 1
