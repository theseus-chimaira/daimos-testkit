        .text
        .globl __start
        .extern OPTIONAL,NEEDED
__start:
        movei 1,NEEDED
        halt .
