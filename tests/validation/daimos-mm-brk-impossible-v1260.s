; Native PDP-6 BRK: a valid but physically impossible new APR extent
; must return physical NOMEM without swapping any other process.
        .text
        .globl main
main:
        movei   1,0776000             ; actual F07 stress request
        pushj   17,vm_space_brk_current
        camn    1,[-1]
        jrst    check_cause_v1260
        movei   1,1
        popj    17,
check_cause_v1260:
        camn    2,[-1]
        jrst    check_metadata_v1260
        movei   1,2
        popj    17,
check_metadata_v1260:
        move    1,proc_desc_v1260+1
        camn    1,[044000,,020000]
        jrst    check_brk_v1260
        movei   1,3
        popj    17,
check_brk_v1260:
        move    1,uarea_v1260+0407
        camn    1,[020000,,030000]
        jrst    check_swap_v1260
        movei   1,4
        popj    17,
check_swap_v1260:
        skipn   calls_swap_v1260
        jrst    check_alloc_v1260
        movei   1,5
        popj    17,
check_alloc_v1260:
        skipn   calls_alloc_v1260
        jrst    check_move_v1260
        movei   1,6
        popj    17,
check_move_v1260:
        skipn   calls_move_v1260
        jrst    check_same_extent_v1260
        movei   1,7
        popj    17,

        ; Same sized APR resize remains valid, commits just the exact
        ; BRK word and does not invoke the impossible-capacity test.
check_same_extent_v1260:
        movei   1,043000
        pushj   17,vm_space_brk_current
        caie    1,043000
        jrst    fail8_v1260
        move    1,uarea_v1260+0407
        camn    1,[020000,,043000]
        jrst    check_invalid_v1260
        jrst    fail9_v1260

        ; A break below the initial image/stack floor is a validation
        ; failure (-4), NOT a physical MM NOMEM (-1).
check_invalid_v1260:
        movei   1,017777
        pushj   17,vm_space_brk_current
        camn    1,[-1]
        jrst    check_invalid_cause_v1260
        jrst    fail10_v1260
check_invalid_cause_v1260:
        camn    2,[-4]
        jrst    check_invalid_unchanged_v1260
        jrst    fail11_v1260
check_invalid_unchanged_v1260:
        move    1,uarea_v1260+0407
        camn    1,[020000,,043000]
        jrst    pass_v1260
        jrst    fail12_v1260
pass_v1260:
        setz    1,
        popj    17,
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

        .globl proc_swap_reclaim
proc_swap_reclaim:
        aos     calls_swap_v1260
        seto    1,
        popj    17,
        .globl mm_alloc_aligned
mm_alloc_aligned:
        aos     calls_alloc_v1260
        seto    1,
        popj    17,
        .globl fs_zero_words
fs_zero_words:
        aos     calls_move_v1260
        popj    17,
        .globl fs_move_words
fs_move_words:
        aos     calls_move_v1260
        popj    17,
        .globl fs_copy_words
fs_copy_words:
        aos     calls_move_v1260
        popj    17,
        .globl mm_free
mm_free:
        setz    1,
        popj    17,
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        halt    .
        .globl mach_pi_disable
mach_pi_disable:
        setz    1,
        popj    17,
        .globl mach_pi_restore
mach_pi_restore:
        setz    1,
        popj    17,

        .data
        .globl kconst_1_1
kconst_1_1: .word 1,,1
        .globl kconst_2_2
kconst_2_2: .word 2,,2
        .globl proc_current_ptr
proc_current_ptr: .word proc_desc_v1260
        .globl proc_current_slot
proc_current_slot: .word 3
proc_desc_v1260:
        .word uarea_v1260,,0400000
        .word 044000,,020000
        .word 0200024,,0
        .globl mm_arenas
mm_arenas:
        .word 0730333,,047445
        .block 2
        .globl mm_arena_count
mm_arena_count: .word 1
        .globl mm_extent_count
mm_extent_count: .word 0
        .globl vm_pdp6_apr
vm_pdp6_apr: .word 0
uarea_v1260:
        .block 0407
        .word 020000,,030000

        .bss
        .globl mm_extents
mm_extents: .block 4
        .globl __test_exit
__test_exit: .block 1
calls_swap_v1260: .block 1
calls_alloc_v1260: .block 1
calls_move_v1260: .block 1
