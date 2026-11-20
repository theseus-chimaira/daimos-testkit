; Real PDP-6 mm_is_pinned returns one atomic advisory MM snapshot.
; The instrumented MM leaf changes the descriptor after lookup only
; when PI remains globally enabled; an unsafe implementation is caught.
        .text
        .globl main
main:
        cono    0004,000200
        pushj   17,reset_v1711
        setom   inject_v1711
        movei   1,02000
        pushj   17,mm_is_pinned
        jumpn   1,fail1_v1711
        skipn   injected_v1711
        jrst    check_unpinned_v1711
        jrst    fail2_v1711
check_unpinned_v1711:
        move    1,mm_extents+1
        came    1,[01,,02]
        jrst    fail3_v1711
        coni    0004,1
        trnn    1,000200
        jrst    fail4_v1711

        ; A pinned extent remains pinned under a stable read.
        move    1,[011,,02]
        movem   1,mm_extents+1
        movei   1,02000
        pushj   17,mm_is_pinned
        caie    1,1
        jrst    fail5_v1711

        ; Missing base still returns false without observing a slot.
        movei   1,03000
        pushj   17,mm_is_pinned
        jumpn   1,fail6_v1711

        ; A caller with PI already disabled must not be reenabled.
        cono    0004,000400
        movei   1,02000
        pushj   17,mm_is_pinned
        caie    1,1
        jrst    fail7_v1711
        coni    0004,1
        trne    1,000200
        jrst    fail8_v1711
        setz    1,
        popj    17,

reset_v1711:
        movei   1,1
        movem   1,mm_extent_count
        move    1,[02000,,02000]
        movem   1,mm_extents
        move    1,[01,,02]
        movem   1,mm_extents+1
        setzm   inject_v1711
        setzm   injected_v1711
        popj    17,

fail1_v1711: movei 1,1
        popj 17,
fail2_v1711: movei 1,2
        popj 17,
fail3_v1711: movei 1,3
        popj 17,
fail4_v1711: movei 1,4
        popj 17,
fail5_v1711: movei 1,5
        popj 17,
fail6_v1711: movei 1,6
        popj 17,
fail7_v1711: movei 1,7
        popj 17,
fail8_v1711: movei 1,010
        popj 17,

        .bss
        .globl mm_extent_count
        .globl mm_extents
        .globl inject_v1711
        .globl injected_v1711
        .globl __test_exit
mm_extent_count: .block 1
mm_extents: .block 4
inject_v1711: .block 1
injected_v1711: .block 1
__test_exit: .block 1
