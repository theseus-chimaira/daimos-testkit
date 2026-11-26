        .text
        .globl main
        .globl rh18_probe_v1977
main:
        jrst    rh18_probe_v1977
        .bss
        .globl __test_exit
__test_exit: .block 1
