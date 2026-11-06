; Native PDP-6: reject impossible aligned extents before any victim I/O.
        .text
        .globl main
main:
        ; Guest evidence: arena 0730333,,047445, single arena; BRK
        ; asks for 0776000 words, exceeding the largest possible image.
        move    1,[0730333,,047445]
        movem   1,mm_arenas
        movei   1,1
        movem   1,mm_arena_count
        movei   1,0776000
        movei   2,02000
        pushj   17,mm_arena_fits_v1260
        jumpn   1,fail1_v1260

        ; The aligned maximum is exactly 0730000. Test both sides
        ; of this boundary, including the unaligned arena origin.
        movei   1,0730000
        movei   2,02000
        pushj   17,mm_arena_fits_v1260
        jumpe   1,fail2_v1260
        movei   1,0730001
        movei   2,02000
        pushj   17,mm_arena_fits_v1260
        jumpn   1,fail3_v1260

        ; At unit alignment the entire arena can fit exactly.
        movei   1,0730333
        movei   2,1
        pushj   17,mm_arena_fits_v1260
        jumpe   1,fail4_v1260

        ; A second sufficient arena wins even if the first is tiny.
        move    1,[01000,,02000]
        movem   1,mm_arenas
        move    1,[0200000,,040000]
        movem   1,mm_arenas+1
        movei   1,2
        movem   1,mm_arena_count
        movei   1,0100000
        movei   2,02000
        pushj   17,mm_arena_fits_v1260
        jumpe   1,fail5_v1260

        ; No arena is a true impossibility; syntactically invalid zero
        ; arguments are passed to the usual typed allocator unchanged.
        setzm   mm_arena_count
        movei   1,02000
        movei   2,02000
        pushj   17,mm_arena_fits_v1260
        jumpn   1,fail6_v1260
        setz    1,
        movei   2,02000
        pushj   17,mm_arena_fits_v1260
        jumpe   1,fail7_v1260
        movei   1,02000
        setz    2,
        pushj   17,mm_arena_fits_v1260
        jumpe   1,fail8_v1260

        ; Actual mm_alloc_aligned (not a reimplementation): a correctly
        ; typed NOMEM from the first attempt must *not* call reclaim.
        move    1,[0730333,,047445]
        movem   1,mm_arenas
        movei   1,1
        movem   1,mm_arena_count
        setzm   calls_nr_v1260
        setzm   calls_fs_v1260
        setzm   calls_swap_v1260
        setzm   calls_compact_v1260
        setom   simulated_result_v1260
        movei   1,0776000
        pushj   17,allocate_v1260
        camn    1,[-1]
        jrst    check_impossible_v1260
        jrst    fail9_v1260
check_impossible_v1260:
        move    1,calls_nr_v1260
        caie    1,1
        jrst    fail10_v1260
        skipn   calls_fs_v1260
        jrst    check_swap_zero_v1260
        jrst    fail11_v1260
check_swap_zero_v1260:
        skipn   calls_swap_v1260
        jrst    check_compact_v1260
        jrst    fail11_v1260
check_compact_v1260:
        skipn   calls_compact_v1260
        jrst    check_possible_v1260
        jrst    fail12_v1260

        ; A feasible arena with temporary pressure must retain the
        ; existing bounded reclamation behavior and typed result.
check_possible_v1260:
        move    1,[0200000,,040000]
        movem   1,mm_arenas
        setzm   calls_nr_v1260
        setzm   calls_fs_v1260
        setzm   calls_swap_v1260
        movei   1,0100000
        pushj   17,allocate_v1260
        camn    1,[-1]
        jrst    check_reclaim_v1260
        jrst    fail13_v1260
check_reclaim_v1260:
        skipn   calls_fs_v1260
        jrst    fail14_v1260
        skipn   calls_swap_v1260
        jrst    fail15_v1260

        ; Typed invalid arguments retain -4 rather than turning into -1.
        setzm   calls_fs_v1260
        setzm   calls_swap_v1260
        movni   1,4
        movem   1,simulated_result_v1260
        movei   1,0776000
        pushj   17,allocate_v1260
        camn    1,[-4]
        jrst    check_invalid_v1260
        jrst    fail16_v1260
check_invalid_v1260:
        skipn   calls_fs_v1260
        jrst    check_invalid_swap_v1260
        jrst    fail17_v1260
check_invalid_swap_v1260:
        skipn   calls_swap_v1260
        jrst    pass_v1260
        jrst    fail17_v1260
pass_v1260:
        setz    1,
        popj    17,

allocate_v1260:
        push    17,[0]
        movei   2,(17)
        push    17,2
        push    17,[1]
        movei   2,02000
        movei   3,1
        movei   4,3
        pushj   17,mm_alloc_aligned
        sub     17,[3,,3]
        popj    17,

; The allocator's effectful helpers are test mocks, not alternative MM
; implementations. Their invocation counts prove no victim is reclaimed
; for an extent which could never fit into any physical arena.
        .globl mm_alloc_aligned_noreclaim
mm_alloc_aligned_noreclaim:
        aos     calls_nr_v1260
        move    1,simulated_result_v1260
        popj    17,
        .globl proc_swap_reclaim
proc_swap_reclaim:
        aos     calls_swap_v1260
        setz    1,
        popj    17,
        .globl fs_memory_reclaim
fs_memory_reclaim:
        aos     calls_fs_v1260
        setz    1,
        popj    17,
        .globl mm_compact
mm_compact:
        aos     calls_compact_v1260
        move    1,simulated_result_v1260
        popj    17,

fail1_v1260: movei 1,1
        popj 17,
fail2_v1260: movei 1,2
        popj 17,
fail3_v1260: movei 1,3
        popj 17,
fail4_v1260: movei 1,4
        popj 17,
fail5_v1260: movei 1,5
        popj 17,
fail6_v1260: movei 1,6
        popj 17,
fail7_v1260: movei 1,7
        popj 17,
fail8_v1260: movei 1,010
        popj 17,
fail9_v1260: movei 1,011
        popj 17,
fail10_v1260: movei 1,012
        popj 17,
fail11_v1260: movei 1,013
        popj 17,
fail12_v1260: movei 1,014
        popj 17,
fail13_v1260: movei 1,015
        popj 17,
fail14_v1260: movei 1,016
        popj 17,
fail15_v1260: movei 1,017
        popj 17,
fail16_v1260: movei 1,020
        popj 17,
fail17_v1260: movei 1,021
        popj 17,

        .bss
        .globl __test_exit
__test_exit: .block 1
        .globl mm_arenas
mm_arenas: .block 3
        .globl mm_arena_count
mm_arena_count: .block 1
calls_nr_v1260: .block 1
calls_fs_v1260: .block 1
calls_swap_v1260: .block 1
calls_compact_v1260: .block 1
simulated_result_v1260: .block 1
