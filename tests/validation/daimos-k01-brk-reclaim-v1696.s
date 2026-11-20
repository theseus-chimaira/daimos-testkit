; Native PDP-6 BRK: a hard MM reclaim refusal must stop pressure,
; retain the current resident extent and report its exact typed cause.
        .text
        .globl main
main:
        move    1,[-4]
        movem   1,reclaim_result_v1696
        pushj   17,brk_call_v1696
        came    1,[-1]
        jrst    fail1_v1696
        came    2,[-4]
        jrst    fail2_v1696
        pushj   17,check_common_v1696
        jumpn   1,fail3_v1696
        skipn   alloc_calls_v1696
        jrst    case_busy_v1696
        jrst    fail4_v1696

case_busy_v1696:
        pushj   17,reset_calls_v1696
        move    1,[-5]
        movem   1,reclaim_result_v1696
        pushj   17,brk_call_v1696
        came    1,[-1]
        jrst    fail5_v1696
        came    2,[-5]
        jrst    fail6_v1696
        pushj   17,check_common_v1696
        jumpn   1,fail7_v1696
        skipn   alloc_calls_v1696
        jrst    case_pressure_v1696
        jrst    fail8_v1696

case_pressure_v1696:
        ; A normal no-victim result is still allowed to try full
        ; allocation once; it must not be treated as a hard MM refusal.
        pushj   17,reset_calls_v1696
        seto    1,
        movem   1,reclaim_result_v1696
        pushj   17,brk_call_v1696
        came    1,[-1]
        jrst    fail9_v1696
        came    2,[-1]
        jrst    fail10_v1696
        pushj   17,check_common_v1696
        jumpn   1,fail11_v1696
        move    1,alloc_calls_v1696
        caie    1,1
        jrst    fail12_v1696
        setz    1,
        popj    17,

brk_call_v1696:
        movei   1,03000
        pushj   17,vm_space_brk_current
        popj    17,

reset_calls_v1696:
        setzm   reclaim_calls_v1696
        setzm   alloc_calls_v1696
        setzm   copy_calls_v1696
        setzm   free_calls_v1696
        popj    17,

check_common_v1696:
        move    1,reclaim_calls_v1696
        caie    1,1
        jrst    check_bad_v1696
        skipn   copy_calls_v1696
        jrst    check_free_v1696
        jrst    check_bad_v1696
check_free_v1696:
        skipn   free_calls_v1696
        jrst    check_vm_v1696
        jrst    check_bad_v1696
check_vm_v1696:
        move    1,proc_desc_v1696+1
        came    1,[02000,,020000]
        jrst    check_bad_v1696
        move    1,uarea_v1696+0407
        came    1,[02000,,02000]
        jrst    check_bad_v1696
        move    1,mm_extent_count
        caie    1,3
        jrst    check_bad_v1696
        move    1,mm_extents+2
        came    1,[02000,,020000]
        jrst    check_bad_v1696
        move    1,mm_extents+3
        came    1,[01,,03]
        jrst    check_bad_v1696
        setz    1,
        popj    17,
check_bad_v1696:
        seto    1,
        popj    17,

fail1_v1696: movei 1,1
        popj 17,
fail2_v1696: movei 1,2
        popj 17,
fail3_v1696: movei 1,3
        popj 17,
fail4_v1696: movei 1,4
        popj 17,
fail5_v1696: movei 1,5
        popj 17,
fail6_v1696: movei 1,6
        popj 17,
fail7_v1696: movei 1,7
        popj 17,
fail8_v1696: movei 1,010
        popj 17,
fail9_v1696: movei 1,011
        popj 17,
fail10_v1696: movei 1,012
        popj 17,
fail11_v1696: movei 1,013
        popj 17,
fail12_v1696: movei 1,014
        popj 17,

        .globl fs_provider_reg_call
fs_provider_reg_call:
        seto    1,                     ; no borrowed MEMFS XIP
        popj    17,
        .globl proc_swap_reclaim
proc_swap_reclaim:
        aos     reclaim_calls_v1696
        move    1,reclaim_result_v1696
        popj    17,
        .globl mm_alloc_aligned
mm_alloc_aligned:
        aos     alloc_calls_v1696
        seto    1,                     ; resource pressure is not a bug
        popj    17,
        .globl mm_free
mm_free:
        aos     free_calls_v1696
        setz    1,
        popj    17,
        .globl fs_zero_words
fs_zero_words:
        aos     copy_calls_v1696
        popj    17,
        .globl fs_move_words
fs_move_words:
        aos     copy_calls_v1696
        popj    17,
        .globl fs_copy_words
fs_copy_words:
        aos     copy_calls_v1696
        popj    17,
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        halt    .

        .data
        .globl kconst_1_1
kconst_1_1: .word 1,,1
        .globl kconst_2_2
kconst_2_2: .word 2,,2
        .globl proc_current_ptr
proc_current_ptr: .word proc_desc_v1696
        .globl proc_current_slot
proc_current_slot: .word 3
proc_desc_v1696:
        .word uarea_v1696,,0400000
        .word 02000,,020000
        .word 0200024,,0
        .globl mm_arenas
mm_arenas:
        .word 014000,,016000        ; end 032000, can hold 04000
        .block 2
        .globl mm_arena_count
mm_arena_count: .word 1
        .globl mm_extent_count
mm_extent_count: .word 3
        .globl mm_extents
mm_extents:
        .word 02000,,016000
        .word 02,,0
        .word 02000,,020000
        .word 01,,03
        .word 02000,,022000
        .word 02,,0
        .globl vm_pdp6_apr
vm_pdp6_apr: .word 0
uarea_v1696:
        .block 0407
        .word 02000,,02000
reclaim_result_v1696: .word 0
        .bss
reclaim_calls_v1696: .block 1
alloc_calls_v1696: .block 1
free_calls_v1696: .block 1
copy_calls_v1696: .block 1
        .globl __test_exit
__test_exit: .block 1
