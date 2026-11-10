/* Verify the staged encoder validates address geometry before stores. */
        .text
        .globl main
        .globl d6codec_kcore_encode_v055
main:
        move    0,[012345670123]
        movem   0,destination
        ; The two-word source would cross physical address 0777777.
        movei   1,0777777
        movei   2,2
        movei   3,destination
        movei   4,3
        pushj   17,d6codec_kcore_encode_v055
        camn    1,[-1]
        jrst    check_source_guard
        jrst    fail1
check_source_guard:
        move    0,destination
        came    0,[012345670123]
        jrst    fail1
        ; Destination capacity crosses the physical memory endpoint.
        movei   1,source
        movei   2,1
        movei   3,0777777
        movei   4,3
        pushj   17,d6codec_kcore_encode_v055
        camn    1,[-1]
        jrst    check_high_pointer
        jrst    fail2
check_high_pointer:
        move    1,[01000000]
        movei   2,1
        movei   3,destination
        movei   4,3
        pushj   17,d6codec_kcore_encode_v055
        camn    1,[-1]
        jrst    check_overlap
        jrst    fail3
check_overlap:
        movei   1,source
        movei   2,1
        movei   3,source
        movei   4,3
        pushj   17,d6codec_kcore_encode_v055
        camn    1,[-1]
        jrst    check_valid
        jrst    fail4
check_valid:
        ; A nonempty input with no output space must not write.
        move    0,[012345670123]
        movem   0,destination
        movei   1,source
        movei   2,1
        movei   3,destination
        setz    4,
        pushj   17,d6codec_kcore_encode_v055
        camn    1,[-1]
        jrst    check_zero_capacity_guard
        jrst    fail5
check_zero_capacity_guard:
        move    0,destination
        came    0,[012345670123]
        jrst    fail5
        ; Empty input and zero capacity form a valid empty stream.
        movei   1,source
        setz    2,
        movei   3,destination
        setz    4,
        pushj   17,d6codec_kcore_encode_v055
        jumpn   1,fail5
        move    0,destination
        came    0,[012345670123]
        jrst    fail5
        movei   1,source
        movei   2,1
        movei   3,destination
        movei   4,3
        pushj   17,d6codec_kcore_encode_v055
        caie    1,2
        jrst    fail5
        move    0,destination
        came    0,[010000000000]
        jrst    fail6
        move    0,destination+1
        came    0,[052]
        jrst    fail7
        move    0,source
        came    0,[052]
        jrst    fail7
        setz    1,
        popj    17,
fail7:
        movei   1,7
        popj    17,
fail6:
        movei   1,6
        popj    17,
fail5:
        movei   1,5
        popj    17,
fail4:
        movei   1,4
        popj    17,
fail3:
        movei   1,3
        popj    17,
fail2:
        movei   1,2
        popj    17,
fail1:
        movei   1,1
        popj    17,
        .data
source:
        .word   052
        .bss
destination: .block 3
        .globl __test_exit
__test_exit: .block 1
