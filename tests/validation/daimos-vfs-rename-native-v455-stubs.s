        .text
        .globl fs_provider_reg_call
fs_provider_reg_call:
        aos     rename_test_calls
        movem   6,rename_test_op
        setz    1,
        popj    17,
        .bss
        .globl rename_test_calls
rename_test_calls: .block 1
        .globl rename_test_op
rename_test_op: .block 1
