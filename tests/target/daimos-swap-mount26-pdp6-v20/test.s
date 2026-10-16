; Production PURE backing native leaves: the 36-bit record's four mount
; bits plus one process-private credential bit distinguish mounts 10 and 26.
; Maximal 18-bit index and 14-bit text must survive unchanged.
        .text
        .globl main
main:
        movei   0,1
        movem   0,stage
        movei   3,7
        lsh     3,036
        movem   3,volume_roots+031     ; slot 25, public mount ID 26
        movem   3,volume_roots+011     ; slot 9, public mount ID 10
        movei   1,0777777             ; maximal 18-bit vnode index
        movei   3,011                 ; low four bits of slot 25
        lsh     3,022
        ior     1,3
        movei   3,037777              ; maximal 14-bit PURE words
        lsh     3,026
        ior     1,3
        movem   1,backing_record

        movei   1,child_uarea
        hrlm    1,process_table+3     ; slot 1 owns this stable u-area
        movei   1,0400000
        iorm    1,process_table+3      ; PROC_F_UAREA
        movei   1,012345
        hrlm    1,process_table+6     ; SIDL entry PC, NOT a u-area pointer
        move    1,backing_record
        movem   1,child_uarea+0406
        movei   1,1
        lsh     1,033
        movem   1,child_uarea+066     ; mount-slot bit 4
        move    1,backing_record
        movei   2,child_uarea
        pushj   17,proc_swap_unpack_backing
        jumpn   1,check26
        jrst    test_fail
check26:
        caie    2,037777
        jrst    test_fail
        ldb     3,[POINT 6,1,5]
        caie    3,7
        jrst    test_fail
        ldb     3,[POINT 6,1,11]
        caie    3,032                 ; public mount ID 26
        jrst    test_fail
        ldb     3,[POINT 6,1,17]
        caie    3,2                   ; TSFS node kind
        jrst    test_fail
        hrrz    3,1
        caie    3,0777777
        jrst    test_fail
        movei   0,2
        movem   0,stage

        move    1,backing_record
        movei   2,child_uarea
        movem   1,backup
        movei   1,032                 ; mount26 busy while PURE text is pinned
        pushj   17,proc_swap_mount_busy
        jumpe   1,test_fail
        movei   1,012                 ; mount10 must NOT be considered busy
        pushj   17,proc_swap_mount_busy
        jumpn   1,test_fail
        movei   0,3
        movem   0,stage
        movei   1,7
        lsh     1,036
        movei   3,032
        lsh     3,030
        ior     1,3
        movei   3,2
        lsh     3,022
        ior     1,3
        iori    1,0777777
        pushj   17,proc_swap_backing_busy
        jumpe   1,test_fail
        movei   1,7
        lsh     1,036
        movei   3,012
        lsh     3,030
        ior     1,3
        movei   3,2
        lsh     3,022
        ior     1,3
        iori    1,0777777
        pushj   17,proc_swap_backing_busy
        jumpn   1,test_fail
        movei   0,4
        movem   0,stage

        ; Clearing ONLY the spare bit changes the decoded slot from 25 to 9.
        ; The backing record itself remains byte-for-byte identical.
        setzm   child_uarea+066
        move    1,backing_record
        movei   2,child_uarea
        pushj   17,proc_swap_unpack_backing
        ldb     3,[POINT 6,1,11]
        caie    3,012                 ; public mount ID 10
        jrst    test_fail
        movei   1,012
        pushj   17,proc_swap_mount_busy
        jumpe   1,test_fail
        movei   1,032
        pushj   17,proc_swap_mount_busy
        jumpn   1,test_fail
        movei   0,5
        movem   0,stage
        movei   1,1
        lsh     1,033
        movem   1,child_uarea+066
        setzm   volume_roots+031
        move    1,backing_record
        movei   2,child_uarea
        pushj   17,proc_swap_unpack_backing
        jumpn   1,test_fail
        jumpn   2,test_fail
        move    3,backing_record
        came    3,backup
        jrst    test_fail
        ; An obsolete/corrupt slot beyond the currently published limit
        ; must be rejected before accessing the MM-backed root table.
        movei   3,7
        lsh     3,036
        movem   3,volume_roots+031
        movei   3,020
        movem   3,vfs_mount_limit
        move    1,backing_record
        movei   2,child_uarea
        pushj   17,proc_swap_unpack_backing
        jumpn   1,test_fail
        jumpn   2,test_fail
        setz    1,
        popj    17,
test_fail:
        move    1,stage
        popj    17,

        .data
        .globl vfs_mount_root_base
vfs_mount_root_base: .word volume_roots
        .globl vfs_mount_limit
vfs_mount_limit: .word 032
        .globl proc_table
proc_table: .word process_table
        .globl proc_high_slot
proc_high_slot: .word 3
        .bss
volume_roots: .block 032
process_table: .block 011
child_uarea: .block 0410
backing_record: .block 1
backup: .block 1
stage: .block 1
        .globl __test_exit
__test_exit: .block 1
