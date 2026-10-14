/* The meta LH is NOT a u-area address without PROC_F_UAREA in meta RH. */
.text
.globl main
main:
        move    1,[0400000,,0]       ; stale entry PC, no UAREA flag
        movem   1,proc_store+3
        hlrz    2,proc_store+3
        caie    2,0400000
        jrst    fail_5
        movei   1,1
        pushj   17,proc_swap_mount_busy
        jumpn   1,fail_1
        coni    0,5
        trne    5,010000               ; no non-existent-memory access
        jrst    fail_6
        movei   1,1
        pushj   17,proc_swap_backing_busy
        jumpn   1,fail_2
        coni    0,5
        trne    5,010000
        jrst    fail_7
        ; A valid resident u-area with no PURE backing is not busy either.
        movei   1,valid_uarea
        hrlm    1,proc_store+3
        movei   1,0400000
        hrrm    1,proc_store+3
        movei   1,1
        pushj   17,proc_swap_mount_busy
        jumpn   1,fail_3
        movei   1,1
        pushj   17,proc_swap_backing_busy
        jumpn   1,fail_4
        setz    1,
        popj    17,
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
.text
.globl vfs_read_words
vfs_read_words: seto 1,
        popj 17,
.globl d6lz36_decode_vfs
d6lz36_decode_vfs: seto 1,
        popj 17,
.data
.globl proc_table
proc_table: .word proc_store
.globl proc_high_slot
proc_high_slot: .word 2
.bss
proc_store: .block 6
valid_uarea: .block 0410
.globl __test_exit
__test_exit: .block 1
