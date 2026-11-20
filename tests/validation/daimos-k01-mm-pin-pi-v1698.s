; Atomic pin/unpin: neither a free nor a second pin can interrupt the
; read/modify/write interval of the physical MM descriptor.
        .text
        .globl main
main:
        cono    0004,000200             ; globally enable PI for the test
        pushj   17,setup_v1698
        pushj   17,pin_v1698
        jumpn   1,fail1_v1698
        move    1,mm_extents+1
        came    1,[011,,01]
        jrst    fail2_v1698
        pushj   17,pin_v1698
        jumpn   1,fail3_v1698
        move    1,mm_extents+1
        came    1,[021,,01]
        jrst    fail4_v1698
        pushj   17,unpin_v1698
        jumpn   1,fail5_v1698
        move    1,mm_extents+1
        came    1,[011,,01]
        jrst    fail6_v1698
        pushj   17,unpin_v1698
        jumpn   1,fail7_v1698
        move    1,mm_extents+1
        came    1,[01,,01]
        jrst    fail8_v1698
        pushj   17,unpin_v1698
        came    1,[-4]
        jrst    fail9_v1698
        movei   1,03000
        pushj   17,mm_pin
        came    1,[-4]
        jrst    fail10_v1698

        ; A theoretical interrupt-side free must not delete a record
        ; after mm_pin has looked it up but before storing its new pin.
        pushj   17,setup_v1698
        setom   inject_add_v1698
        pushj   17,pin_v1698
        jumpn   1,fail11_v1698
        move    1,mm_extents+1
        came    1,[011,,01]
        jrst    fail12_v1698
        move    1,mm_extent_count
        caie    1,1
        jrst    fail13_v1698
        skipn   injected_add_v1698
        jrst    test_unpin_interrupt_v1698
        jrst    fail14_v1698

test_unpin_interrupt_v1698:
        ; An interrupt-side extra pin must not be overwritten by a
        ; stale unpin's zero-count publication.
        setom   inject_sub_v1698
        pushj   17,unpin_v1698
        jumpn   1,fail15_v1698
        move    1,mm_extents+1
        came    1,[01,,01]
        jrst    fail16_v1698
        skipn   injected_sub_v1698
        jrst    final_pi_v1698
        jrst    fail17_v1698

final_pi_v1698:
        coni    0004,1
        trne    1,000200               ; caller's PI state restored
        jrst    test_pi_off_v1698
        jrst    fail18_v1698
test_pi_off_v1698:
        ; Calling from an already-PI-disabled section must not enable
        ; global interrupts when the nested pin operation returns.
        cono    0004,000400
        pushj   17,pin_v1698
        jumpn   1,fail19_v1698
        coni    0004,1
        trnn    1,000200
        jrst    success_v1698
        jrst    fail20_v1698
success_v1698:
        setz    1,
        popj    17,

pin_v1698:
        movei   1,02000
        pushj   17,mm_pin
        popj    17,
unpin_v1698:
        movei   1,02000
        pushj   17,mm_unpin
        popj    17,
setup_v1698:
        movei   1,1
        movem   1,mm_extent_count
        move    1,[02000,,02000]
        movem   1,mm_extents
        move    1,[01,,01]
        movem   1,mm_extents+1
        setzm   inject_add_v1698
        setzm   inject_sub_v1698
        setzm   injected_add_v1698
        setzm   injected_sub_v1698
        popj    17,

fail1_v1698: movei 1,1
        popj 17,
fail2_v1698: movei 1,2
        popj 17,
fail3_v1698: movei 1,3
        popj 17,
fail4_v1698: movei 1,4
        popj 17,
fail5_v1698: movei 1,5
        popj 17,
fail6_v1698: movei 1,6
        popj 17,
fail7_v1698: movei 1,7
        popj 17,
fail8_v1698: movei 1,010
        popj 17,
fail9_v1698: movei 1,011
        popj 17,
fail10_v1698: movei 1,012
        popj 17,
fail11_v1698: movei 1,013
        popj 17,
fail12_v1698: movei 1,014
        popj 17,
fail13_v1698: movei 1,015
        popj 17,
fail14_v1698: movei 1,016
        popj 17,
fail15_v1698: movei 1,017
        popj 17,
fail16_v1698: movei 1,020
        popj 17,
fail17_v1698: movei 1,021
        popj 17,
fail18_v1698: movei 1,022
        popj 17,
fail19_v1698: movei 1,023
        popj 17,
fail20_v1698: movei 1,024
        popj    17,

        .bss
        .globl mm_extent_count
        .globl mm_extents
        .globl inject_add_v1698
        .globl inject_sub_v1698
        .globl injected_add_v1698
        .globl injected_sub_v1698
        .globl __test_exit
mm_extent_count: .block 1
mm_extents: .block 4
inject_add_v1698: .block 1
inject_sub_v1698: .block 1
injected_add_v1698: .block 1
injected_sub_v1698: .block 1
__test_exit: .block 1
