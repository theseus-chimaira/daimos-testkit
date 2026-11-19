; v1659: unchanged original MM allocator, pin, unpin and free leaves.
; Genuine arena [040000,050363) contains one pinned RAW suffix
; [040000,046600) of 06600 octal (3456) words. Remaining gap is
; 01563 octal (883) words; bitmap candidate is 0241 octal (161).
        .text
        .globl main
        .globl mm_alloc_aligned_noreclaim
        .globl mm_pin
        .globl mm_unpin
        .globl mm_free

main:
        setzm   base_v1659
        movei   1,0241                  ; 161 words, not aligned APR
        pushj   17,allocate_v1659
        jumpn   1,failed_v1659
        move    1,base_v1659
        caie    1,050122                ; HIGH end of exact 883 gap
        jrst    failed_v1659
        move    1,mm_extent_count
        caie    1,2
        jrst    failed_v1659
        move    1,mm_extents
        camn    1,[06600,,040000]
        jrst    verify_raw_v1659
        jrst    failed_v1659
verify_raw_v1659:
        move    1,mm_extents+1
        camn    1,[014,,2]              ; one original RAW pin, owner2
        jrst    verify_bitmap_v1659
        jrst    failed_v1659
verify_bitmap_v1659:
        move    1,mm_extents+2
        camn    1,[0241,,050122]
        jrst    verify_bitmap_owner_v1659
        jrst    failed_v1659
verify_bitmap_owner_v1659:
        move    1,mm_extents+3
        camn    1,[04,,2]               ; PACKED_PROCESS, owner2, pin0
        jrst    bitmap_pin_v1659
        jrst    failed_v1659
bitmap_pin_v1659:
        move    1,base_v1659
        pushj   17,mm_pin
        jumpn   1,failed_v1659
        move    1,mm_extents+3
        camn    1,[014,,2]
        jrst    bitmap_unpin_v1659
        jrst    failed_v1659
bitmap_unpin_v1659:
        move    1,base_v1659
        pushj   17,mm_unpin
        jumpn   1,failed_v1659
        move    1,base_v1659
        movei   2,4
        movei   3,2
        pushj   17,mm_free
        jumpn   1,failed_v1659
        move    1,mm_extent_count
        caie    1,1
        jrst    failed_v1659
        move    1,mm_extents
        camn    1,[06600,,040000]
        jrst    shortage_v1659
        jrst    failed_v1659
shortage_v1659:
        setzm   base_v1659
        movei   1,01564                 ; 884 > free 883: NOMEM
        pushj   17,allocate_v1659
        camn    1,[-1]
        jrst    capacity_v1659
        jrst    failed_v1659
capacity_v1659:
        skipn   base_v1659
        jrst    try_capacity_v1659
        jrst    failed_v1659
try_capacity_v1659:
        movei   1,1
        movem   1,mm_extent_capacity
        movei   1,0241
        pushj   17,allocate_v1659
        camn    1,[-3]                  ; descriptor limit
        jrst    verify_final_v1659
        jrst    failed_v1659
verify_final_v1659:
        move    1,mm_extent_count
        caie    1,1
        jrst    failed_v1659
        move    1,mm_extents+1
        camn    1,[014,,2]              ; RAW still pinned
        jrst    source_unpin_v1659
        jrst    failed_v1659
source_unpin_v1659:
        movei   1,040000
        pushj   17,mm_unpin
        jumpn   1,failed_v1659
        move    1,mm_extents+1
        camn    1,[04,,2]
        jrst    invalid_type_v1659
        jrst    failed_v1659
invalid_type_v1659:
        ; Reject reserved 5..7 and out-of-field 8, including values
        ; with high bits set. No failed allocation may insert an extent.
        setzm   base_v1659
        movei   3,5
        pushj   17,allocate_bad_v1659
        camn    1,[-4]
        jrst    invalid_seven_v1659
        jrst    failed_v1659
invalid_seven_v1659:
        movei   3,7
        pushj   17,allocate_bad_v1659
        camn    1,[-4]
        jrst    invalid_eight_v1659
        jrst    failed_v1659
invalid_eight_v1659:
        movei   3,010
        pushj   17,allocate_bad_v1659
        camn    1,[-4]
        jrst    invalid_negative_v1659
        jrst    failed_v1659
invalid_negative_v1659:
        seto    3,
        pushj   17,allocate_bad_v1659
        camn    1,[-4]
        jrst    invalid_zero_v1659
        jrst    failed_v1659
invalid_zero_v1659:
        setz    3,
        pushj   17,allocate_bad_v1659
        camn    1,[-4]
        jrst    rejected_no_growth_v1659
        jrst    failed_v1659
rejected_no_growth_v1659:
        skipn   base_v1659
        jrst    check_count_v1659
        jrst    failed_v1659
check_count_v1659:
        move    1,mm_extent_count
        caie    1,1
        jrst    failed_v1659
        move    1,mm_extents+1
        camn    1,[04,,2]
        jrst    success_v1659
        jrst    failed_v1659
success_v1659:
        setz    1,
        popj    17,
failed_v1659:
        movei   1,1
        popj    17,

allocate_v1659:
        movei   3,4                     ; MM_TYPE_PACKED_PROCESS
        jrst    allocate_common_v1659
allocate_bad_v1659:
        movei   1,0241                  ; common invalid-type test size
allocate_common_v1659:
        movei   2,1
        movei   4,2                     ; process slot2
        movei   5,base_v1659
        push    17,5                    ; sixth: output base pointer
        push    17,[1]                  ; fifth: MM_ALLOC_HIGH
        pushj   17,mm_alloc_aligned_noreclaim
        sub     17,[2,,2]
        popj    17,

        .data
        .globl mm_arena_count
mm_arena_count: .word 1
        .globl mm_arenas
mm_arenas: .word 010363,,040000
           .block 2
        .globl mm_extent_capacity
mm_extent_capacity: .word 4
        .globl mm_extent_count
mm_extent_count: .word 1
        .globl mm_extents
mm_extents: .word 06600,,040000
            .word 014,,2
            .block 010
base_v1659: .word 0
        .bss
        .globl __test_exit
__test_exit: .block 1
