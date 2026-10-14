/* Native PDP-6 bounded reclaim policy and failure atomicity. */
.text
.globl main
main:
        movei 1,1
        movem 1,mm_arena_count
        move 1,[04000,,020000]
        movem 1,mm_arenas
        movei 1,0100000
        movem 1,mm_core_words
        setzm mm_extent_count
        setzm fs_calls
        setzm swap_calls
        movei 1,077777
        movem 1,chosen
        ; Request more than the entire arena, retry must be bounded.
        movei 1,05000
        movei 2,1
        movei 3,2
        movei 4,7
        movei 5,chosen
        push 17,5
        push 17,[0]
        pushj 17,mm_alloc_aligned
        sub 17,[2,,2]
        came 1,[-1]
        jrst fail_1
        move 1,fs_calls
        caie 1,2
        jrst fail_2
        move 1,swap_calls
        caie 1,1
        jrst fail_3
        move 1,chosen
        caie 1,077777
        jrst fail_4
        skipn mm_extent_count
        jrst first_good
        jrst fail_5
first_good:
        ; Critical no-reclaim variant must never invoke callbacks.
        setzm fs_calls
        setzm swap_calls
        movei 1,05000
        movei 2,1
        movei 3,2
        movei 4,7
        movei 5,chosen
        push 17,5
        push 17,[0]
        pushj 17,mm_alloc_aligned_noreclaim
        sub 17,[2,,2]
        came 1,[-1]
        jrst fail_6
        skipn fs_calls
        jrst fs_good
        jrst fail_7
fs_good:
        skipn swap_calls
        jrst swap_good
        jrst fail_8
swap_good:
        ; A reclaim callback frees a real MM extent; the allocator retries.
        setzm mm_extent_count
        setzm fs_calls
        setzm swap_calls
        movei 1,1
        movem 1,reclaim_enabled
        movei 1,020000
        movem 1,reclaim_base
        movei 1,1
        movem 1,mm_extent_count
        move 1,[04000,,020000]
        movem 1,mm_extents
        move 1,[2,,7]
        movem 1,mm_extents+1
        movei 1,077777
        movem 1,chosen
        movei 1,04000
        movei 2,1
        movei 3,2
        movei 4,7
        movei 5,chosen
        push 17,5
        push 17,[0]
        pushj 17,mm_alloc_aligned
        sub 17,[2,,2]
        jumpn 1,fail_9
        move 1,chosen
        caie 1,020000
        jrst fail_10
        move 1,fs_calls
        caie 1,1
        jrst fail_11
        skipn swap_calls
        jrst swap_success
        jrst fail_12
swap_success:
        move 1,mm_extent_count
        caie 1,1
        jrst fail_13
        ; Exhaust metadata with physically available memory: retry must
        ; return descriptor failure without reclaim or publishing base.
        setzm reclaim_enabled
        setzm fs_calls
        setzm swap_calls
        movei 1,040
        movem 1,mm_extent_count
        ; Build a sorted, valid 32-descriptor table with interleaved gaps.
        ; Two words per descriptor, each one physical word long.
        setz 6,
        movei 7,020000
fill_descriptors:
        move 5,[1,,0]
        hrr 5,7
        movem 5,mm_extents(6)
        move 5,[2,,7]
        movem 5,mm_extents+1(6)
        addi 7,2
        addi 6,2
        caige 6,0100
        jrst fill_descriptors
        movei 1,077777
        movem 1,chosen
        movei 1,0100
        movei 2,1
        movei 3,2
        movei 4,7
        movei 5,chosen
        push 17,5
        push 17,[0]
        pushj 17,mm_alloc_aligned
        sub 17,[2,,2]
        came 1,[-3]
        jrst fail_14
        move 1,chosen
        caie 1,077777
        jrst fail_15
        move 1,mm_extent_count
        caie 1,040
        jrst fail_16
        ; The current allocator retries descriptor failure through its
        ; bounded pressure sequence. Verify exact callback bounds.
        move 1,fs_calls
        caie 1,2
        jrst fail_17
        move 1,swap_calls
        caie 1,1
        jrst fail_18
desc_swap_ok:
        ; The 31->32 boundary must work with the same valid sorted table.
        movei 1,037
        movem 1,mm_extent_count
        setzm fs_calls
        setzm swap_calls
        movei 1,077777
        movem 1,chosen
        movei 1,1
        movei 2,1
        movei 3,2
        movei 4,7
        movei 5,chosen
        push 17,5
        push 17,[0]
        pushj 17,mm_alloc_aligned_noreclaim
        sub 17,[2,,2]
        jumpn 1,fail_19
        move 1,chosen
        caie 1,020001
        jrst fail_20
        move 1,mm_extent_count
        caie 1,040
        jrst fail_21
        ; Removing the inserted descriptor returns exactly one slot.
        movei 1,020001
        movei 2,2
        movei 3,7
        pushj 17,mm_free
        jumpn 1,fail_22
        move 1,mm_extent_count
        caie 1,037
        jrst fail_23
        skipn fs_calls
        jrst capacity_fs_ok
        jrst fail_24
capacity_fs_ok:
        skipn swap_calls
        jrst capacity_done
        jrst fail_25
capacity_done:
        setz 1,
        popj 17,
fail_1: movei 1,1
        popj 17,
fail_2: movei 1,2
        popj 17,
fail_3: movei 1,3
        popj 17,
fail_4: movei 1,4
        popj 17,
fail_5: movei 1,5
        popj 17,
fail_6: movei 1,6
        popj 17,
fail_7: movei 1,7
        popj 17,
fail_8: movei 1,010
        popj 17,
fail_9: movei 1,11
        popj 17,
fail_10: movei 1,12
        popj 17,
fail_11: movei 1,13
        popj 17,
fail_12: movei 1,14
        popj 17,
fail_13: movei 1,15
        popj 17,
fail_14: movei 1,16
        popj 17,
fail_15: movei 1,17
        popj 17,
fail_16: movei 1,20
        popj 17,
fail_17: movei 1,21
        popj 17,
fail_18: movei 1,22
        popj 17,
fail_19: movei 1,23
        popj 17,
fail_20: movei 1,24
        popj 17,
fail_21: movei 1,25
        popj 17,
fail_22: movei 1,26
        popj 17,
fail_23: movei 1,27
        popj 17,
fail_24: movei 1,30
        popj 17,
fail_25: movei 1,31
        popj 17,
.bss
chosen: .block 1
.globl __test_exit
__test_exit: .block 1
