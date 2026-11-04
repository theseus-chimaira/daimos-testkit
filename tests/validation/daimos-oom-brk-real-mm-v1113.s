; v1113: production allocator, VM BRK and OOM-enabled syscall dispatch.
; Real gaps/descriptor capacity cause -2/-3. FS/swap observers cannot
; reclaim anything from this isolated native machine-state fixture.
        .text
        .globl main
main:
        movei   17,__stack-1
        hrli    17,-0400
        ; Arena 02000..020000; current process cannot grow upward.
        movei   1,4
        movem   1,mm_extent_count
        movem   1,mm_extent_capacity
        move    1,[02000,,02000]
        movem   1,mm_extents
        move    1,[1,,2]
        movem   1,mm_extents+1
        move    1,[02000,,04000]
        movem   1,mm_extents+2
        move    1,[3,,3]
        movem   1,mm_extents+3
        move    1,[02000,,010000]
        movem   1,mm_extents+4
        move    1,[3,,4]
        movem   1,mm_extents+5
        move    1,[02000,,014000]
        movem   1,mm_extents+6
        move    1,[3,,5]
        movem   1,mm_extents+7

        movei   2,02001       ; rounds to 04000 words
        pushj   17,native_sys_brk
        camn    1,[-1]
        jrst    check_fragment_cause_v1113
        jrst    fail_1_v1113
check_fragment_cause_v1113:
        camn    2,[-2]
        jrst    check_fragment_owner_v1113
        jrst    fail_2_v1113
check_fragment_owner_v1113:
        move    1,mm_extent_count
        caie    1,4
        jrst    fail_3_v1113
        move    1,mm_extents
        camn    1,[02000,,02000]
        jrst    check_fragment_vm_v1113
        jrst    fail_4_v1113
check_fragment_vm_v1113:
        move    1,__proc_v1113+1
        camn    1,[02000,,02000]
        jrst    check_fragment_brk_v1113
        jrst    fail_5_v1113
check_fragment_brk_v1113:
        move    1,__uarea_v1113+0407
        camn    1,[01000,,01777]
        jrst    check_compaction_v1113
        jrst    fail_6_v1113
check_compaction_v1113:
        skipn   __compact_calls_v1113
        jrst    fail_14_v1113
        jrst    setup_descriptors_v1113

setup_descriptors_v1113:
        ; Same live current process and blocker; enough continuous free
        ; space for a second process image, but zero free descriptors.
        movei   1,2
        movem   1,mm_extent_count
        movem   1,mm_extent_capacity
        setzm   __reclaim_calls_v1113
        setzm   __compact_calls_v1113
        movei   2,02001
        pushj   17,native_sys_brk
        camn    1,[-1]
        jrst    check_descriptor_cause_v1113
        jrst    fail_7_v1113
check_descriptor_cause_v1113:
        camn    2,[-3]
        jrst    check_descriptor_owner_v1113
        jrst    fail_8_v1113
check_descriptor_owner_v1113:
        move    1,mm_extent_count
        caie    1,2
        jrst    fail_9_v1113
        move    1,__proc_v1113+1
        camn    1,[02000,,02000]
        jrst    check_descriptor_brk_v1113
        jrst    fail_10_v1113
check_descriptor_brk_v1113:
        move    1,__uarea_v1113+0407
        camn    1,[01000,,01777]
        jrst    check_no_fatal_v1113
        jrst    fail_11_v1113
check_no_fatal_v1113:
        skipn   __fatal_calls_v1113
        jrst    check_reclaim_v1113
        jrst    fail_12_v1113
check_reclaim_v1113:
        skipn   __reclaim_calls_v1113
        jrst    fail_13_v1113
        setz    1,
        jrst    done_v1113
fail_1_v1113: movei 1,1
        jrst done_v1113
fail_2_v1113: movei 1,2
        jrst done_v1113
fail_3_v1113: movei 1,3
        jrst done_v1113
fail_4_v1113: movei 1,4
        jrst done_v1113
fail_5_v1113: movei 1,5
        jrst done_v1113
fail_6_v1113: movei 1,6
        jrst done_v1113
fail_7_v1113: movei 1,7
        jrst done_v1113
fail_8_v1113: movei 1,010
        jrst done_v1113
fail_9_v1113: movei 1,011
        jrst done_v1113
fail_10_v1113: movei 1,012
        jrst done_v1113
fail_11_v1113: movei 1,013
        jrst done_v1113
fail_12_v1113: movei 1,014
        jrst done_v1113
fail_13_v1113: movei 1,015
        jrst done_v1113
fail_14_v1113: movei 1,016
done_v1113:
        movem   1,__test_exit
        jrst    4,0

; Standalone native test-only leaf observers, never linked into KCORE.
        .globl proc_swap_reclaim
proc_swap_reclaim:
        aos     __reclaim_calls_v1113
        seto    1,
        popj    17,
        .globl fs_memory_reclaim
fs_memory_reclaim:
        aos     __reclaim_calls_v1113
        setz    1,
        popj    17,
        .globl mm_move_extent
mm_move_extent:
        aos     __compact_calls_v1113
        movni   1,2
        popj    17,
        .globl proc_fatal_close_current_v879
proc_fatal_close_current_v879:
        aos     __fatal_calls_v1113
        popj    17,
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        aos     __fatal_calls_v1113
        popj    17,
        .globl mm_free
mm_free:
        aos     __fatal_calls_v1113
        movni   1,4
        popj    17,
        .globl fs_move_words
        .globl fs_copy_words
        .globl fs_zero_words
fs_move_words:
fs_copy_words:
fs_zero_words:
        popj    17,

        .data
        .globl proc_current_slot
proc_current_slot: .word 2
        .globl proc_current_ptr
proc_current_ptr: .word __proc_v1113
__proc_v1113: .word __uarea_v1113,,0400000
        .word 02000,,02000
        .globl mm_arena_count
mm_arena_count: .word 1
        .globl mm_arenas
mm_arenas: .word 016000,,02000
        .globl mm_extent_capacity
mm_extent_capacity: .word 4
        .globl mm_extent_count
mm_extent_count: .word 4
        .globl mm_extents
mm_extents: .block 12
        .globl kconst_2_2
kconst_2_2: .word 2,,2
        .globl vm_pdp6_apr
vm_pdp6_apr: .word 0
__uarea_v1113: .block 0407
        .word 01000,,01777
__reclaim_calls_v1113: .word 0
__compact_calls_v1113: .word 0
__fatal_calls_v1113: .word 0
        .bss
__stack: .block 0400
        .globl __test_exit
__test_exit: .block 1
