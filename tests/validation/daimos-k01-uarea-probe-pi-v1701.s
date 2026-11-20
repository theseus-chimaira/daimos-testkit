; Read-only GETTEARDOWN MM diagnostic must snapshot one coherent
; u-area owner, type and pin count even if PI-side MM changes occur.
        .text
        .globl main
main:
        cono    0004,000200           ; initial global PI on
        pushj   17,setup_v1701
        setom   inject_v1701
        pushj   17,probe_v1701
        caie    1,1                    ; exactly one u-area pin
        jrst    fail1_v1701
        move    1,mm_extents+1
        came    1,[013,,01003]
        jrst    fail2_v1701
        skipn   injected_v1701
        jrst    check_pi_v1701
        jrst    fail3_v1701
check_pi_v1701:
        coni    0004,1
        trnn    1,000200
        jrst    fail4_v1701

        ; The existing error classes remain stable and distinct.
        move    1,[011,,01003]        ; wrong type: PROCESS
        movem   1,mm_extents+1
        pushj   17,probe_v1701
        caie    1,0401
        jrst    fail5_v1701
        move    1,[013,,01004]        ; incorrect u-area owner
        movem   1,mm_extents+1
        pushj   17,probe_v1701
        caie    1,0402
        jrst    fail6_v1701
        move    1,[03,,01003]         ; exact owner with zero pins
        movem   1,mm_extents+1
        pushj   17,probe_v1701
        jumpn   1,fail7_v1701
        movei   1,03000              ; base absent from MM table
        movei   2,3
        pushj   17,mm_uarea_probe_v887
        caie    1,0400
        jrst    fail8_v1701

        ; Calling from a PI-disabled kernel section must not enable it.
        cono    0004,000400
        pushj   17,probe_v1701
        jumpn   1,fail9_v1701
        coni    0004,1
        trne    1,000200
        jrst    fail10_v1701
        setz    1,
        popj    17,

probe_v1701:
        movei   1,02000
        movei   2,3
        pushj   17,mm_uarea_probe_v887
        popj    17,
setup_v1701:
        movei   1,1
        movem   1,mm_extent_count
        move    1,[02000,,02000]
        movem   1,mm_extents
        move    1,[013,,01003]
        movem   1,mm_extents+1
        setzm   inject_v1701
        setzm   injected_v1701
        popj    17,

fail1_v1701: movei 1,1
        popj 17,
fail2_v1701: movei 1,2
        popj 17,
fail3_v1701: movei 1,3
        popj 17,
fail4_v1701: movei 1,4
        popj 17,
fail5_v1701: movei 1,5
        popj 17,
fail6_v1701: movei 1,6
        popj 17,
fail7_v1701: movei 1,7
        popj 17,
fail8_v1701: movei 1,010
        popj 17,
fail9_v1701: movei 1,011
        popj 17,
fail10_v1701: movei 1,012
        popj 17,

        .bss
        .globl mm_extent_count
        .globl mm_extents
        .globl inject_v1701
        .globl injected_v1701
        .globl __test_exit
mm_extent_count: .block 1
mm_extents: .block 4
inject_v1701: .block 1
injected_v1701: .block 1
__test_exit: .block 1
