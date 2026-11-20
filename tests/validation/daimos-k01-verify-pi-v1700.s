; Real PDP-6 MM exact-extent verifier: snapshot cannot combine the
; old length with metadata read after an interrupt-side length change.
        .text
        .globl main
main:
        cono    0004,000200             ; initially PI enabled
        pushj   17,setup_v1700
        setom   inject_v1700
        move    010,[012345]
        move    011,[054321]
        pushj   17,verify_v1700
        jumpn   1,fail1_v1700
        ; A checked descriptor must not have changed during the read.
        move    1,mm_extents
        came    1,[04000,,02000]
        jrst    fail2_v1700
        skipn   injected_v1700
        jrst    registers_v1700
        jrst    fail3_v1700
registers_v1700:
        move    1,010
        came    1,[012345]
        jrst    fail4_v1700
        move    1,011
        came    1,[054321]
        jrst    fail5_v1700
        coni    0004,1
        trnn    1,000200
        jrst    fail6_v1700

        ; Exact length, owner and sole-pin checks still reject errors.
        movei   1,02000
        movei   2,1
        movei   3,06000
        pushj   17,mm_process_verify_pinned_v792
        came    1,[-1]
        jrst    fail7_v1700
        movei   1,02000
        movei   2,2
        movei   3,04000
        pushj   17,mm_process_verify_pinned_v792
        came    1,[-1]
        jrst    fail8_v1700
        move    1,[021,,01]           ; two pins, not exactly one
        movem   1,mm_extents+1
        pushj   17,verify_v1700
        came    1,[-1]
        jrst    fail9_v1700
        move    1,[011,,01]
        movem   1,mm_extents+1

        ; Disabled global PI must not be enabled by verification.
        cono    0004,000400
        pushj   17,verify_v1700
        jumpn   1,fail10_v1700
        coni    0004,1
        trne    1,000200
        jrst    fail11_v1700
        setz    1,
        popj    17,

verify_v1700:
        movei   1,02000
        movei   2,1
        movei   3,04000
        pushj   17,mm_process_verify_pinned_v792
        popj    17,
setup_v1700:
        movei   1,1
        movem   1,mm_extent_count
        move    1,[04000,,02000]
        movem   1,mm_extents
        move    1,[011,,01]
        movem   1,mm_extents+1
        setzm   inject_v1700
        setzm   injected_v1700
        popj    17,

fail1_v1700: movei 1,1
        popj 17,
fail2_v1700: movei 1,2
        popj 17,
fail3_v1700: movei 1,3
        popj 17,
fail4_v1700: movei 1,4
        popj 17,
fail5_v1700: movei 1,5
        popj 17,
fail6_v1700: movei 1,6
        popj 17,
fail7_v1700: movei 1,7
        popj 17,
fail8_v1700: movei 1,010
        popj 17,
fail9_v1700: movei 1,011
        popj 17,
fail10_v1700: movei 1,012
        popj 17,
fail11_v1700: movei 1,013
        popj 17,

        .bss
        .globl mm_extent_count
        .globl mm_extents
        .globl inject_v1700
        .globl injected_v1700
        .globl __test_exit
mm_extent_count: .block 1
mm_extents: .block 4
inject_v1700: .block 1
injected_v1700: .block 1
__test_exit: .block 1
