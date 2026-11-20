; Native PDP-6 MM allocation must publish exactly one owned extent.
; A competing interrupt-side allocation must not steal the chosen gap
; between mm_find_fit and the real mm_extent_insert publication.
        .text
        .globl main
main:
        cono    0004,000200           ; enter with global PI enabled
        move    016,[012345]          ; caller register must survive MM
        pushj   17,setup_v1702
        setom   inject_v1702
        pushj   17,allocate_v1702
        jumpn   1,fail1_v1702
        move    1,allocated_base_v1702
        caie    1,010000
        jrst    fail2_v1702
        move    1,mm_extent_count
        caie    1,1
        jrst    fail3_v1702
        move    1,mm_extents
        came    1,[02000,,010000]
        jrst    fail4_v1702
        move    1,mm_extents+1
        came    1,[01,,03]
        jrst    fail5_v1702
        skipn   injected_v1702
        jrst    check_register_v1702
        jrst    fail6_v1702
check_register_v1702:
        move    1,016
        came    1,[012345]
        jrst    fail18_v1702
check_pi_v1702:
        coni    0004,1
        trnn    1,000200
        jrst    fail7_v1702

        ; A complete descriptor table must refuse without publishing
        ; any allocation, restoring the previous global PI state.
        pushj   17,setup_v1702
        setzm   mm_extent_capacity
        pushj   17,allocate_v1702
        came    1,[-3]
        jrst    fail8_v1702
        skipn   mm_extent_count
        jrst    check_capacity_pi_v1702
        jrst    fail9_v1702
check_capacity_pi_v1702:
        coni    0004,1
        trnn    1,000200
        jrst    fail10_v1702

        ; Valid arguments with no managed RAM return ordinary -1,
        ; not a forced or fabricated extent owner.
        pushj   17,setup_v1702
        setzm   mm_arena_count
        pushj   17,allocate_v1702
        came    1,[-1]
        jrst    fail11_v1702
        skipn   mm_extent_count
        jrst    check_disabled_v1702
        jrst    fail12_v1702

check_disabled_v1702:
        ; A call from a PI-disabled section never enables PI on exit.
        pushj   17,setup_v1702
        cono    0004,000400
        pushj   17,allocate_v1702
        jumpn   1,fail13_v1702
        coni    0004,1
        trne    1,000200
        jrst    fail14_v1702
        move    1,mm_extent_count
        caie    1,1
        jrst    fail15_v1702

        ; Input validation must not change PI even before acquiring the
        ; MM-table critical section.
        pushj   17,setup_v1702
        push    17,[allocated_base_v1702]
        push    17,[0]
        setz    1,                     ; invalid zero words
        movei   2,02000
        movei   3,1
        movei   4,3
        pushj   17,mm_alloc_aligned_noreclaim
        sub     17,[2,,2]
        came    1,[-4]
        jrst    fail16_v1702
        coni    0004,1
        trne    1,000200
        jrst    fail17_v1702
        setz    1,
        popj    17,

allocate_v1702:
        push    17,[allocated_base_v1702]
        push    17,[0]
        movei   1,02000
        movei   2,02000
        movei   3,1                   ; PROCESS
        movei   4,3                   ; slot owner
        pushj   17,mm_alloc_aligned_noreclaim
        sub     17,[2,,2]
        popj    17,

setup_v1702:
        setzm   mm_extent_count
        movei   1,4
        movem   1,mm_extent_capacity
        movei   1,1
        movem   1,mm_arena_count
        move    1,[020000,,010000]
        movem   1,mm_arenas
        setzm   mm_extents
        setzm   mm_extents+1
        setzm   mm_extents+2
        setzm   mm_extents+3
        setom   allocated_base_v1702
        setzm   inject_v1702
        setzm   injected_v1702
        popj    17,

fail1_v1702: movei 1,1
        popj 17,
fail2_v1702: movei 1,2
        popj 17,
fail3_v1702: movei 1,3
        popj 17,
fail4_v1702: movei 1,4
        popj 17,
fail5_v1702: movei 1,5
        popj 17,
fail6_v1702: movei 1,6
        popj 17,
fail7_v1702: movei 1,7
        popj 17,
fail8_v1702: movei 1,010
        popj 17,
fail9_v1702: movei 1,011
        popj 17,
fail10_v1702: movei 1,012
        popj 17,
fail11_v1702: movei 1,013
        popj 17,
fail12_v1702: movei 1,014
        popj 17,
fail13_v1702: movei 1,015
        popj 17,
fail14_v1702: movei 1,016
        popj 17,
fail15_v1702: movei 1,017
        popj 17,
fail16_v1702: movei 1,020
        popj 17,
fail17_v1702: movei 1,021
        popj 17,
fail18_v1702: movei 1,022
        popj 17,

        .bss
        .globl mm_extent_count
        .globl mm_extent_capacity
        .globl mm_extents
        .globl mm_arena_count
        .globl mm_arenas
        .globl inject_v1702
        .globl injected_v1702
        .globl __test_exit
mm_extent_count: .block 1
mm_extent_capacity: .block 1
mm_extents: .block 010
mm_arena_count: .block 1
mm_arenas: .block 1
allocated_base_v1702: .block 1
inject_v1702: .block 1
injected_v1702: .block 1
__test_exit: .block 1
