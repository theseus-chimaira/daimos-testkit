; Two used extents in a 010000-word arena leave two separate 02000-word
; gaps. A 03000-word request is fragmented despite 04000 free words.
; At capacity two, a smaller fitting request exhausts descriptor slots.
        .text
        .globl main
main:
        movei   17,__stack-1
        hrli    17,-0400

        ; More words requested than all remaining gaps: -1 shortage.
        movei   1,05000
        pushj   17,alloc_v1111
        camn    1,[-1]
        jrst    fragmented_v1111
        jrst    fail_1_v1111
fragmented_v1111:
        movei   1,03000
        pushj   17,alloc_v1111
        camn    1,[-2]
        jrst    descriptors_v1111
        jrst    fail_2_v1111
descriptors_v1111:
        movei   1,01000
        pushj   17,alloc_v1111
        camn    1,[-3]
        jrst    retained_v1111
        jrst    fail_3_v1111
retained_v1111:
        move    1,mm_extent_count
        caie    1,2
        jrst    fail_4_v1111
        move    1,mm_extents
        camn    1,[02000,,02000]
        jrst    retained_second_v1111
        jrst    fail_5_v1111
retained_second_v1111:
        move    1,mm_extents+2
        camn    1,[02000,,06000]
        jrst    recover_v1111
        jrst    fail_6_v1111
recover_v1111:
        movei   1,3
        movem   1,mm_extent_capacity
        movei   1,01000
        pushj   17,alloc_v1111
        jumpn   1,fail_7_v1111
        move    1,__base_v1111
        caie    1,04000
        jrst    fail_8_v1111
        move    1,mm_extent_count
        caie    1,3
        jrst    fail_9_v1111
        move    1,mm_extents+2
        camn    1,[01000,,04000]
        jrst    final_v1111
        jrst    fail_10_v1111
final_v1111:
        move    1,mm_extents+4
        camn    1,[02000,,06000]
        jrst    success_v1111
        jrst    fail_11_v1111
success_v1111:
        setz    1,
        jrst    done_v1111
fail_1_v1111: movei 1,1
        jrst done_v1111
fail_2_v1111: movei 1,2
        jrst done_v1111
fail_3_v1111: movei 1,3
        jrst done_v1111
fail_4_v1111: movei 1,4
        jrst done_v1111
fail_5_v1111: movei 1,5
        jrst done_v1111
fail_6_v1111: movei 1,6
        jrst done_v1111
fail_7_v1111: movei 1,7
        jrst done_v1111
fail_8_v1111: movei 1,010
        jrst done_v1111
fail_9_v1111: movei 1,011
        jrst done_v1111
fail_10_v1111: movei 1,012
        jrst done_v1111
fail_11_v1111: movei 1,013
done_v1111:
        movem   1,__test_exit
        jrst    4,0

; Use the production six-argument allocator leaf without compaction,
; FS reclaim or swapping, so it reports the exact first failure cause.
alloc_v1111:
        movei   2,01000               ; alignment
        movei   3,1                   ; process type
        movei   4,2                   ; process owner
        movei   5,__base_v1111
        push    17,5                  ; sixth argument: &base
        push    17,[0]                ; fifth argument: LOW
        pushj   17,mm_alloc_aligned_noreclaim
        sub     17,[2,,2]
        popj    17,

        .data
        .globl mm_arena_count
mm_arena_count: .word 1
        .globl mm_arenas
mm_arenas: .word 010000,,02000
        .globl mm_extent_capacity
mm_extent_capacity: .word 2
        .globl mm_extent_count
mm_extent_count: .word 2
        .globl mm_extents
mm_extents: .word 02000,,02000
        .word 01,,2
        .word 02000,,06000
        .word 01,,3
        .block 4
__base_v1111: .word 0
        .bss
__stack: .block 0400
        .globl __test_exit
__test_exit: .block 1
