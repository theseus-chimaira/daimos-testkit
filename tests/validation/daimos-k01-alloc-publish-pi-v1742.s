; Native PDP-6 MM allocation must publish exactly one owned extent.
; A competing interrupt-side allocation must not steal the chosen gap
; between mm_find_fit and the real mm_extent_insert publication.
        .text
        .globl main
main:
        cono    0004,000200           ; enter with global PI enabled
        cono    0004,02026            ; enable disk PI3/PI5 and scheduler PI6
        move    016,[012345]          ; caller register must survive MM
        pushj   17,setup_v1742
        setom   inject_v1742
        pushj   17,allocate_v1742
        jumpn   1,fail1_v1742
        move    1,allocated_base_v1742
        caie    1,010000
        jrst    fail2_v1742
        move    1,mm_extent_count
        caie    1,1
        jrst    fail3_v1742
        move    1,mm_extents
        came    1,[02000,,010000]
        jrst    fail4_v1742
        move    1,mm_extents+1
        came    1,[01,,03]
        jrst    fail5_v1742
        skipn   injected_v1742
        jrst    check_register_v1742
        jrst    fail6_v1742
check_register_v1742:
        skipn   pi_global_off_v1742
        jrst    check_disk_levels_v1742
        jrst    fail19_v1742
check_disk_levels_v1742:
        skipn   pi_levels_bad_v1742
        jrst    check_register_live_v1742
        jrst    fail20_v1742
check_register_live_v1742:
        move    1,016
        came    1,[012345]
        jrst    fail18_v1742
check_pi_v1742:
        coni    0004,1
        trnn    1,000200
        jrst    fail7_v1742

        ; A complete descriptor table must refuse without publishing
        ; any allocation, restoring the previous global PI state.
        pushj   17,setup_v1742
        setzm   mm_extent_capacity
        pushj   17,allocate_v1742
        came    1,[-3]
        jrst    fail8_v1742
        skipn   mm_extent_count
        jrst    check_capacity_pi_v1742
        jrst    fail9_v1742
check_capacity_pi_v1742:
        coni    0004,1
        trnn    1,000200
        jrst    fail10_v1742

        ; Valid arguments with no managed RAM return ordinary -1,
        ; not a forced or fabricated extent owner.
        pushj   17,setup_v1742
        setzm   mm_arena_count
        pushj   17,allocate_v1742
        came    1,[-1]
        jrst    fail11_v1742
        skipn   mm_extent_count
        jrst    check_disabled_v1742
        jrst    fail12_v1742

check_disabled_v1742:
        ; A call with PI6 disabled never enables PI6 on exit; disk stays on.
        pushj   17,setup_v1742
        cono    0004,01002
        pushj   17,allocate_v1742
        jumpn   1,fail13_v1742
        coni    0004,1
        trne    1,000002
        jrst    fail14_v1742
        trnn    1,000200
        jrst    fail21_v1742
        move    1,mm_extent_count
        caie    1,1
        jrst    fail15_v1742

        ; Input validation must not change PI even before acquiring the
        ; MM-table critical section.
        pushj   17,setup_v1742
        push    17,[allocated_base_v1742]
        push    17,[0]
        setz    1,                     ; invalid zero words
        movei   2,02000
        movei   3,1
        movei   4,3
        pushj   17,mm_alloc_aligned_noreclaim
        sub     17,[2,,2]
        came    1,[-4]
        jrst    fail16_v1742
        coni    0004,1
        trne    1,000002
        jrst    fail17_v1742
        setz    1,
        popj    17,

allocate_v1742:
        push    17,[allocated_base_v1742]
        push    17,[0]
        movei   1,02000
        movei   2,02000
        movei   3,1                   ; PROCESS
        movei   4,3                   ; slot owner
        pushj   17,mm_alloc_aligned_noreclaim
        sub     17,[2,,2]
        popj    17,

setup_v1742:
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
        setom   allocated_base_v1742
        setzm   inject_v1742
        setzm   injected_v1742
        setzm   pi_global_off_v1742
        setzm   pi_levels_bad_v1742
        popj    17,

fail1_v1742: movei 1,1
        popj 17,
fail2_v1742: movei 1,2
        popj 17,
fail3_v1742: movei 1,3
        popj 17,
fail4_v1742: movei 1,4
        popj 17,
fail5_v1742: movei 1,5
        popj 17,
fail6_v1742: movei 1,6
        popj 17,
fail7_v1742: movei 1,7
        popj 17,
fail8_v1742: movei 1,010
        popj 17,
fail9_v1742: movei 1,011
        popj 17,
fail10_v1742: movei 1,012
        popj 17,
fail11_v1742: movei 1,013
        popj 17,
fail12_v1742: movei 1,014
        popj 17,
fail13_v1742: movei 1,015
        popj 17,
fail14_v1742: movei 1,016
        popj 17,
fail15_v1742: movei 1,017
        popj 17,
fail16_v1742: movei 1,020
        popj 17,
fail17_v1742: movei 1,021
        popj 17,
fail18_v1742: movei 1,022
        popj 17,
fail19_v1742: movei 1,023
        popj 17,
fail20_v1742: movei 1,024
        popj 17,
fail21_v1742: movei 1,025
        popj 17,

        .bss
        .globl mm_extent_count
        .globl mm_extent_capacity
        .globl mm_extents
        .globl mm_arena_count
        .globl mm_arenas
        .globl inject_v1742
        .globl injected_v1742
        .globl pi_global_off_v1742
        .globl pi_levels_bad_v1742
        .globl __test_exit
mm_extent_count: .block 1
mm_extent_capacity: .block 1
mm_extents: .block 010
mm_arena_count: .block 1
mm_arenas: .block 1
allocated_base_v1742: .block 1
inject_v1742: .block 1
injected_v1742: .block 1
pi_global_off_v1742: .block 1
pi_levels_bad_v1742: .block 1
__test_exit: .block 1
