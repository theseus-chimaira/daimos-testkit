; v1536: real PDP-6 BACKSTORE bitmap allocator/free instructions.
; KINIT's v2 persisted MEMFS run is blocks 107..144 inclusive in a
; 145-block backing volume. One independent old process owns block 0.
; Snapshot occupies bitmap[2] bit 35, bitmap[3] all bits, bitmap[4]
; bit 0. An unrelated process must allocate only blocks 1..106.

        .text
        .globl main
main:
        movei   17,__stack-1
        hrli    17,-0400

        ; A 107-block allocation must refuse because the oldest process
        ; still owns block zero and the snapshot owns 107..144.
        movei   1,0153                 ; 107 decimal
        setz    2,
        movei   3,__first
        pushj   17,backstore_alloc
        jumpe   1,fail
        pushj   17,check_initial
        jumpn   1,fail

        ; Refuse a release that covers seven free blocks 100..106
        ; and only the first snapshot block 107. It is NOT an owned
        ; process run. Without the production full-owner preflight,
        ; this would clear snapshot bit 107 and decrement accounting.
        movei   1,0144                 ; 100 decimal
        movei   2,010                  ; 8 decimal
        pushj   17,backstore_free
        jumpe   1,fail
        pushj   17,check_initial
        jumpn   1,fail

        ; Allocate another process's 100 blocks. The first free block
        ; is 1: the caller must never steal old process block 0.
        movei   1,0144                 ; 100 decimal
        movei   2,5
        movei   3,__first
        pushj   17,backstore_alloc
        jumpn   1,fail
        move    1,__first
        caie    1,1
        jrst    fail
        move    1,backstore_blocks_used
        caie    1,0213                 ; 139 decimal
        jrst    fail
        pushj   17,check_snapshot
        jumpn   1,fail

        ; The six remaining ordinary blocks, 101..106, are still
        ; allocatable. Their new owner cannot overlap snapshot 107.
        movei   1,6
        setz    2,
        movei   3,__second
        pushj   17,backstore_alloc
        jumpn   1,fail
        move    1,__second
        caie    1,0145                 ; 101 decimal
        jrst    fail
        move    1,backstore_blocks_used
        caie    1,0221                 ; 145 decimal
        jrst    fail
        pushj   17,check_snapshot
        jumpn   1,fail

        ; All blocks are owned. A later request must fail without
        ; editing the original snapshot or either process descriptor.
        movei   1,1
        setz    2,
        movei   3,__third
        pushj   17,backstore_alloc
        jumpe   1,fail
        move    1,__second
        caie    1,0145
        jrst    fail
        pushj   17,check_snapshot
        jumpn   1,fail

        ; Correctly free only the two temporary process owners.
        movei   1,1
        movei   2,0144
        pushj   17,backstore_free
        jumpn   1,fail
        movei   1,0145
        movei   2,6
        pushj   17,backstore_free
        jumpn   1,fail
        pushj   17,check_initial
        jumpn   1,fail

        ; Neither process may free the already-released 100-block
        ; owner a second time. The snapshot's recorded 38 blocks
        ; and old process's block zero must remain untouched.
        movei   1,1
        movei   2,0144
        pushj   17,backstore_free
        jumpe   1,fail
        pushj   17,check_initial
        jumpn   1,fail

        ; Snapshot run is protected from a duplicate/overlapping
        ; allocation even after temporary processes exit.
        movei   1,0153
        setz    2,
        movei   3,__first
        pushj   17,backstore_alloc
        jumpe   1,fail
        pushj   17,check_initial
        jumpn   1,fail
        jrst    success

check_initial:
        move    1,backstore_blocks_used
        caie    1,047                  ; 39 decimal
        jrst    check_fail
        move    1,__bitmap
        caie    1,1
        jrst    check_fail
        skipn   __bitmap+1
        jrst    check_initial_more
        jrst    check_fail
check_initial_more:
        move    1,__bitmap+2
        came    1,[0400000000000]
        jrst    check_fail
        pushj   17,check_snapshot
        popj    17,

check_snapshot:
        move    1,__bitmap+3
        came    1,[0777777777777]
        jrst    check_fail
        move    1,__bitmap+4
        caie    1,1
        jrst    check_fail
        setz    1,
        popj    17,
check_fail:
        movei   1,1
        popj    17,
success:
        setz    1,
        jrst    finish
fail:
        movei   1,1
finish:
        movem   1,__test_exit
        jrst    4,0

        .data
        .globl backstore_bitmap
backstore_bitmap:       .word __bitmap
        .globl backstore_blocks
backstore_blocks:       .word 0221
        .globl backstore_blocks_used
backstore_blocks_used:  .word 047
        .globl backstore_enabled
backstore_enabled:      .word 1
__bitmap:               .word 1
                        .word 0
                        .word 0400000000000
                        .word 0777777777777
                        .word 1
__first:                .word 0
__second:               .word 0
__third:                .word 0
        .bss
        .globl __test_exit
__test_exit:            .block 1
__stack:                .block 0400
