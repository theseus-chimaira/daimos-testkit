        .text
        .globl badmap_map_test
        .globl badmap_map_block
        .globl kret_neg1

; C ABI: AC1 logical, AC2 unitp, AC3 blockp.
badmap_map_test:
        jumpe   2,kret_neg1
        jumpe   3,kret_neg1
        push    17,2
        push    17,3
        pushj   17,badmap_map_block
        move    4,2
        pop     17,3
        pop     17,2
        jumpl   1,kret_neg1
        movem   1,(2)
        movem   4,(3)
        setz    1,
        popj    17,

        .globl badmap_patch_test_backends
        .globl badmap_backend_read_jump
        .globl badmap_backend_write_jump

badmap_patch_test_backends:
        move    1,[jrst badmap_test_read_backend]
        movem   1,badmap_backend_read_jump
        move    1,[jrst badmap_test_write_backend]
        movem   1,badmap_backend_write_jump
        popj    17,

badmap_test_read_backend:
        movei   4,1
        movem   4,badmap_test_op
        jrst    badmap_test_capture
badmap_test_write_backend:
        movei   4,2
        movem   4,badmap_test_op
badmap_test_capture:
        movem   1,badmap_test_unit
        movem   2,badmap_test_block
        movem   3,badmap_test_buffer
        setz    1,
        popj    17,

        .bss
        .globl badmap_test_unit
        .globl badmap_test_block
        .globl badmap_test_buffer
        .globl badmap_test_op
badmap_test_unit:   .block 1
badmap_test_block:  .block 1
badmap_test_buffer: .block 1
badmap_test_op:     .block 1
