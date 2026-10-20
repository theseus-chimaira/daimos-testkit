        .text
        .globl  _start
_start:
        move    17,[0777700,,test_stack-1]
        pushj   17,daimos_snap_target_v72
        movem   1,daimos_snap_result_v72
        halt    .

        .bss
test_stack:      .block 0400
