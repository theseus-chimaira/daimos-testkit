        .text
        .globl  _start
_start:
        move    17,[0777700,,stack-1]
        pushj   17,daimos_file_walk_pdp6_test
        movem   1,daimos_file_walk_pdp6_result
        halt    .

        .bss
stack:  .block  0200
