; Target oracle for TSFS D6LZ restart extent integration.
        .text
        .globl main
        .globl dtfs_dtc_read
        .globl dtfs_media
        .globl fs_block_workspace
        .globl fs_copy_words
        .globl kret_zero
        .globl kret_neg1
        .globl fs_mres_vector_dispatch
        .globl vfs_mount
        .globl vfs_mount_prevalidated
        .globl vfs_name_valid
        .globl vfs_name_from_words
        .globl vfs_name_words_equal
        .globl fs_words_equal
        .globl vfs_sixbit_name_chars
        .globl tsfs_file_shape
        .globl tsfs_extent_media
        .globl tsfs_read_words
        .globl mm_alloc
        .globl mm_free
        .globl d6lz36_decode_core
        .globl vfs_read_words
        .globl bcache_reclaim

main:
        move    1,[700002,,4]
        movem   1,dtfs_media
        movei   1,4                    ; logical member 0 -> DTC4
        movem   1,tsfs_file_shape
        move    1,[700001,,5]
        movem   1,tsfs_extent_media

        movei   1,7
        lsh     1,036
        movei   2,0102
        lsh     2,022
        ior     1,2
        iori    1,1
        movei   2,010
        movei   3,result
        movei   4,020
        pushj   17,tsfs_read_words
        movem   1,debug_count
        caie    1,020
        jrst    fail_count
        movei   5,0
check_loop:
        move    1,result(5)
        movei   2,03010(5)
        came    1,2
        jrst    fail_data
        addi    5,1
        caige   5,020
        jrst    check_loop
        move    1,alloc_state
        caie    1,2
        jrst    fail_free
        setz    1,
        popj    17,
fail_count: movei 1,1
        popj    17,
fail_data:  movei 1,2
        popj    17,
fail_free:  movei 1,3
        popj    17,

dtfs_dtc_read:
        caie    1,7
        jrst    dtc_data
        caie    2,4
        jrst    dtc_extent
        push    17,3
        pushj   17,clear_block
        pop     17,3
        movei   4,1
        movem   4,0(3)
        move    4,[1,,1]
        movem   4,7(3)
        movei   4,2
        movem   4,010(3)
        movei   4,0400
        movem   4,015(3)
        move    4,[0,,1]
        movem   4,016(3)
        setz    1,
        popj    17,
dtc_extent:
        caie    2,5
        jrst    kret_neg1
        push    17,3
        pushj   17,clear_block
        pop     17,3
        setzm   0(3)
        movei   4,6
        movem   4,1(3)
        move    4,[1,,1]
        movem   4,2(3)
        setz    1,
        popj    17,
dtc_data:
        caie    1,4
        jrst    kret_neg1
        caie    2,6
        jrst    kret_neg1
        push    17,3
        pushj   17,clear_block
        pop     17,3
        movei   4,0400
        movem   4,0(3)
        movei   4,1
        movem   4,1(3)
        movei   4,012345
        movem   4,2(3)
        setz    1,
        popj    17,

; mm_alloc fifth argument is basep at -1(17).
mm_alloc:
        move    5,-1(17)
        movei   6,decodebuf
        movem   6,(5)
        movei   6,1
        movem   6,alloc_state
        setz    1,
        popj    17,
mm_free:
        caie    1,decodebuf
        jrst    kret_neg1
        movei   6,2
        movem   6,alloc_state
        setz    1,
        popj    17,

; Integration stub: fill the destination exactly as a successful D6LZ core
; would and consume the one-word source window.
d6lz36_decode_core:
        movei   5,0
decode_loop:
        movei   6,03000(5)
        movem   6,0(12)
        aoj     12,
        addi    5,1
        sojg    13,decode_loop
        setz    4,
        setz    0,
        popj    17,

; The direct-buffer D6LZ test must never enter the VFS refill side.
vfs_read_words:
        jrst    kret_neg1

; Unmount/media-change cache invalidation is outside this focused read test.
bcache_reclaim:
        jrst    kret_zero

clear_block:
        movei   4,0
clear_loop:
        setzm   0(3)
        addi    3,1
        addi    4,1
        caige   4,0200
        jrst    clear_loop
        popj    17,

fs_copy_words:
        jumpe   3,kret_zero
copy_loop:
        move    4,0(1)
        movem   4,0(2)
        addi    1,1
        addi    2,1
        sojg    3,copy_loop
kret_zero:
        setz    1,
        popj    17,
kret_neg1:
        hrroi   1,1
        popj    17,
fs_mres_vector_dispatch:
vfs_mount:
vfs_mount_prevalidated:
vfs_name_valid:
fs_words_equal:
        jrst    kret_neg1

; Canonical VFS-name helpers used by the other entry points collected in
; tsfs_runtime.s.  This D6LZ read oracle does not call those entry points, but
; the direct object link must still satisfy their current production ABI.
vfs_name_words_equal:
        jumpe   3,vfs_name_words_equal_yes
vfs_name_words_equal_loop:
        move    4,(1)
        came    4,(2)
        jrst    kret_zero
        aoj     1,
        aoj     2,
        sojg    3,vfs_name_words_equal_loop
vfs_name_words_equal_yes:
        movei   1,1
        popj    17,

vfs_name_from_words:
        push    17,1
        push    17,2
        movei   2,030
        pushj   17,vfs_sixbit_name_chars
        move    4,1
        move    1,-1(17)
        move    2,(17)
        movei   5,1(2)
        hrl     5,1
        blt     5,4(2)
        movem   4,(2)
        sub     17,[2,,2]
        popj    17,

vfs_sixbit_name_chars:
        jumpe   1,kret_zero
        jumpe   2,kret_zero
        caile   2,030
        jrst    kret_zero
        move    3,[POINT 6,0]
        hrr     3,1
        setz    4,
        setz    5,
vfs_name_chars_loop:
        ildb    6,3
        addi    5,1
        jumpe   6,vfs_name_chars_next
        move    4,5
vfs_name_chars_next:
        came    5,2
        jrst    vfs_name_chars_loop
        move    1,4
        popj    17,

        .bss
dtfs_media:             .block 4
fs_block_workspace:     .block 0200
decodebuf:              .block 0400
result:                 .block 020
        .globl alloc_state
alloc_state:            .block 1
        .globl debug_count
debug_count:            .block 1
        .globl __test_exit
__test_exit:             .block 1
