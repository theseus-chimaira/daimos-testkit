; Actual production TSFS parent/parent_name helpers with a controlled
; physical file-record callback.  Real vfs_name_from_words is linked.
; A successful parent vnode is NONZERO; only negative means failure.
        .text
        .globl main
        .globl tsfs_parent
        .globl tsfs_parent_name
        .globl tsfs_file_record
        .globl kret_zero
        .globl kret_neg1
        .globl kconst_2_2
        .globl __test_exit

main:
        movei   1,1
        movem   1,record_ready_v1525
        setzm   record_v1525
        move    1,[446420000000]       ; SIXBIT DT0, 3 chars
        movem   1,record_v1525+1
        movei   1,1
        movem   1,stage_v1525

        ; Child record 5 of TSFS mount kind NODE. Parent is TSFS root.
        movsi   1,070002
        hrr     1,[5]
        movei   2,parent_result_v1525
        movei   3,name_result_v1525
        pushj   17,tsfs_parent_name
        jumpn   1,fail_v1525
        move    4,parent_result_v1525
        came    4,[070001000000]
        jrst    fail_v1525
        move    4,name_result_v1525
        caie    4,3
        jrst    fail_v1525
        move    4,name_result_v1525+1
        came    4,[446420000000]
        jrst    fail_v1525

        movei   4,2
        movem   4,stage_v1525
        movei   1,5
        movsi   1,070002
        hrr     1,[5]
        movei   2,parent_result_v1525
        setzm   parent_result_v1525
        pushj   17,tsfs_parent
        jumpn   1,fail_v1525
        move    4,parent_result_v1525
        came    4,[070001000000]
        jrst    fail_v1525

        ; An intermediate directory has its own nonzero parent record
        ; index; the provider must report the proper NODE kind.
        movei   4,3
        movem   4,stage_v1525
        move    4,[11,,0]
        movem   4,record_v1525
        movsi   1,070002
        hrr     1,[5]
        movei   2,parent_result_v1525
        movei   3,name_result_v1525
        pushj   17,tsfs_parent_name
        jumpn   1,fail_v1525
        move    4,parent_result_v1525
        came    4,[070002000011]
        jrst    fail_v1525

        ; A missing record is a hard negative. A negative return must
        ; neither publish a false parent nor write the name destination.
        movei   4,4
        movem   4,stage_v1525
        setzm   record_ready_v1525
        movei   4,0777
        movem   4,parent_result_v1525
        movem   4,name_result_v1525
        movsi   1,070002
        hrr     1,[5]
        movei   2,parent_result_v1525
        movei   3,name_result_v1525
        pushj   17,tsfs_parent_name
        camn    1,[-1]
        jrst    missing_record_checked_v1525
        jrst    fail_v1525
missing_record_checked_v1525:
        move    4,parent_result_v1525
        caie    4,0777
        jrst    fail_v1525
        move    4,name_result_v1525
        caie    4,0777
        jrst    fail_v1525
        setz    1,
        popj    17,

fail_v1525:
        move    1,stage_v1525
        popj    17,

; The only controlled boundary is retrieval of a TSFS file record.
; No TSFS parent logic is mocked or reimplemented in this fixture.
tsfs_file_record:
        skipn   record_ready_v1525
        jrst    kret_neg1
        movei   1,record_v1525
        popj    17,
kret_zero:
        setz    1,
        popj    17,
kret_neg1:
        seto    1,
        popj    17,

        .data
kconst_2_2: .word 2,,2
record_ready_v1525: .word 0
stage_v1525: .word 0
record_v1525: .block 010
parent_result_v1525: .word 0
name_result_v1525: .block 5
__test_exit: .word 0
