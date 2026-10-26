        .text
        .globl symlink_test_operation
        .globl symlink_test_argument_e
        .globl symlink_test_output
        .globl fs_provider_reg_call
fs_provider_reg_call:
        movem   6,symlink_test_operation
        movem   5,symlink_test_argument_e
        movem   3,symlink_test_output
        movei   0,0123
        movem   0,(4)
        setz    1,
        popj    17,
        .bss
symlink_test_operation: .block 1
symlink_test_argument_e: .block 1
symlink_test_output: .block 1
