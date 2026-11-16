        .text
        .globl  _start
_start:
        move    17,[0777700,,stack-1]
        pushj   17,daimos_d6fs_free_fcb_bound_v1_test
        movem   1,daimos_d6fs_free_fcb_bound_v1_result
        halt    .

        .bss
stack:  .block  0200
