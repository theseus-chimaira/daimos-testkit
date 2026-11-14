; v1552: real production MM allocation, pin, unpin and release leaves.
; Only the already-tested Type-551 arm service is replaced by an oracle.
        .text
        .globl main
        .globl __test_exit
        .globl dtfs_intent_owned_arm_v1552
        .globl dtfs_intent_arm_v1551
        .globl dtfs_intent_verify_v1554
        .globl dtfs_intent_clean_v1566
        .globl dtfs_mark_unit_suspect_v1522
        .globl mm_is_pinned
        .globl mm_extent_count
        .globl mm_arena_count
        .globl mm_extents
        .globl mm_extent_capacity
        .globl mm_arenas

main:
        setzm   base_v1552
        setzm   arm_calls_v1552
        movei   1,2
        movei   2,0123
        movei   3,0456
        movei   4,base_v1552
        pushj   17,dtfs_intent_owned_arm_v1552
        jumpn   1,fail_v1552
        skipn   arm_calls_v1552
        jrst    fail_v1552
        skipn   base_v1552
        jrst    count_check_v1552
        jrst    fail_v1552
count_check_v1552:
        skipn   mm_extent_count
        jrst    do_second_v1552
        jrst    fail_v1552

do_second_v1552:
        ; Actual allocator must be able to reuse the same 0200 words.
        movei   1,2
        movei   2,0123
        movei   3,0456
        movei   4,base_v1552
        pushj   17,dtfs_intent_owned_arm_v1552
        jumpn   1,fail_v1552
        move    1,arm_calls_v1552
        caie    1,2
        jrst    fail_v1552
        skipn   mm_extent_count
        jrst    allocation_failure_v1552
        jrst    fail_v1552

allocation_failure_v1552:
        ; With the only arena removed, this is a genuine MM shortage.
        setzm   mm_arena_count
        movei   1,2
        movei   2,0123
        movei   3,0456
        movei   4,base_v1552
        pushj   17,dtfs_intent_owned_arm_v1552
        camn    1,[-1]
        jrst    no_mm_no_arm_v1552
        jrst    fail_v1552
no_mm_no_arm_v1552:
        skipn   base_v1552
        jrst    no_mm_count_v1552
        jrst    fail_v1552
no_mm_count_v1552:
        skipn   mm_extent_count
        jrst    arm_count_v1552
        jrst    fail_v1552
arm_count_v1552:
        move    1,arm_calls_v1552
        caie    1,2
        jrst    fail_v1552
        setz    1,
        popj    17,
fail_v1552:
        movei   1,1
        popj    17,

; Type-551 arm stub checks that the actual MM allocated the exact
; dynamic kernel scratch, that it remains pinned during I/O, and that
; allocation did not corrupt an independent data buffer.
dtfs_intent_arm_v1551:
        aos     arm_calls_v1552
        caie    1,2
        jrst    arm_failed_v1552
        caie    2,0123
        jrst    arm_failed_v1552
        caie    3,0456
        jrst    arm_failed_v1552
        move    010,4
        move    1,010
        pushj   17,mm_is_pinned
        caie    1,1
        jrst    arm_failed_v1552
        move    1,mm_extent_count
        caie    1,1
        jrst    arm_failed_v1552
        hrrz    1,mm_extents
        came    1,010
        jrst    arm_failed_v1552
        hlrz    1,mm_extents
        caie    1,0200
        jrst    arm_failed_v1552
        move    1,mm_extents+1
        hrrz    2,1
        caie    2,015                   ; reserved DTFS intent owner
        jrst    arm_failed_v1552
        hlrz    2,1
        andi    2,7
        caie    2,3                     ; MM_TYPE_KERNEL_DYNAMIC
        jrst    arm_failed_v1552
        movei   2,07777
        movem   2,(010)                 ; touch actual pinned scratch
        setz    1,
        popj    17,
arm_failed_v1552:
        seto    1,
        popj    17,

dtfs_intent_verify_v1554:
        seto    1,
        popj    17,

; The historical v1552 physical-MM matrix does not run v1566 CLEAN.
; Keep the new compiled branch linked without pretending to seal RBN0.
dtfs_intent_clean_v1566:
        seto    1,
        popj    17,
dtfs_mark_unit_suspect_v1522:
        seto    1,
        popj    17,

        .data
        .globl mm_arena_count
mm_arena_count: .word 1
        .globl mm_arenas
mm_arenas: .word 02000,,04000
           .block 2
        .globl mm_extent_capacity
mm_extent_capacity: .word 020
        .globl mm_extent_count
mm_extent_count: .word 0
        .globl mm_extents
mm_extents: .block 040
base_v1552: .word 0
arm_calls_v1552: .word 0
        .bss
__test_exit: .block 1
