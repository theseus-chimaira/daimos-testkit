; Target oracle for TSFS multi-extent/cross-member reads.
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
        .globl d6lz36_decode_buffer
        .globl bcache_reclaim

main:
        ; FILE table: physical DTC7, two records, block 4.
        move    1,[700002,,4]
        movem   1,dtfs_media
        ; Logical members 0,1,2 -> physical DTC 4,1,7.
        movei   1,0714
        movem   1,tsfs_file_shape
        ; EXTENT table: physical DTC7, two records, block 5.
        move    1,[700002,,5]
        movem   1,tsfs_extent_media

        ; vnode = provider 7, mount 1/local kind 2, file record 1.
        movei   1,7
        lsh     1,036
        movei   2,0102
        lsh     2,022
        ior     1,2
        iori    1,1
        movei   2,0370                 ; eight words before 0400 restart boundary
        movei   3,result
        movei   4,030                  ; 24 words: 8 + 16 across members
        pushj   17,tsfs_read_words
        caie    1,030
        jrst    test_fail_count

        movei   5,0
check_first:
        move    1,result(5)
        movei   2,01370(5)
        came    1,2
        jrst    test_fail_data0
        addi    5,1
        caige   5,010
        jrst    check_first

        movei   5,0
check_second:
        move    1,result+010(5)
        movei   2,02000(5)
        came    1,2
        jrst    test_fail_data1
        addi    5,1
        caige   5,020
        jrst    check_second
        setz    1,
        popj    17,

test_fail_count: movei 1,1
        popj    17,
test_fail_data0: movei 1,2
        popj    17,
test_fail_data1: movei 1,3
        popj    17,

; AC1=unit, AC2=block, AC3=destination.  Return 0 or -1.
dtfs_dtc_read:
        caie    1,7
        jrst    dtc_data
        caie    2,4
        jrst    dtc_extent
        push    17,3
        pushj   17,clear_block
        pop     17,3
        ; Record zero root directory.
        movei   4,1
        movem   4,0(3)
        move    4,[1,,1]
        movem   4,7(3)
        ; Record one regular file, 512 words, two 256-word restarts.
        movei   4,2
        movem   4,010(3)
        movei   4,01000
        movem   4,015(3)
        movei   4,2
        movem   4,016(3)
        setz    1,
        popj    17,

dtc_extent:
        caie    2,5
        jrst    kret_neg1
        push    17,3
        pushj   17,clear_block
        pop     17,3
        ; Extent 0: file word 0, logical member 0, block 6, two blocks.
        setzm   0(3)
        movei   4,6
        movem   4,1(3)
        movei   4,2
        movem   4,2(3)
        ; Extent 1: file word 0400, logical member 1, block 6, two blocks.
        movei   4,0400
        movem   4,4(3)
        move    4,[1,,6]
        movem   4,5(3)
        movei   4,2
        movem   4,6(3)
        setz    1,
        popj    17,

dtc_data:
        caige   2,6
        jrst    kret_neg1
        caile   2,7
        jrst    kret_neg1
        caie    1,4
        jrst    dtc_data1
        movei   4,01000
dtc_data_offset:
        move    5,2
        subi    5,6
        lsh     5,7
        add     4,5
        jrst    dtc_fill
dtc_data1:
        caie    1,1
        jrst    kret_neg1
        movei   4,02000
        jrst    dtc_data_offset
dtc_fill:
        movei   5,0
dtc_fill_loop:
        move    6,4
        add     6,5
        movem   6,0(3)
        addi    3,1
        addi    5,1
        caige   5,0200
        jrst    dtc_fill_loop
        setz    1,
        popj    17,

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

; Canonical VFS-name helpers used by other entry points in tsfs_runtime.s.
; The read-words oracle does not call those entry points, but keeping the
; production helper semantics here prevents the direct object link from
; depending on unrelated VFS/provider code.
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

mm_alloc:
mm_free:
d6lz36_decode_buffer:
d6lz36_decode_core:
        jrst    kret_neg1

; Mount-path cache invalidation is not exercised by this direct read oracle.
bcache_reclaim:
        jrst    kret_zero

        .bss
dtfs_media:             .block 4
fs_block_workspace:     .block 0200
result:                 .block 030
        .globl __test_exit
__test_exit:             .block 1
