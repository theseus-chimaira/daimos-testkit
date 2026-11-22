        .text
        .globl __start
        .extern OPTIONAL,NEEDED
__start:
        .word NEEDED,,0
        halt .
