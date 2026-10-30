        .text
        .globl main
main:
        movei 17,__stack-1
        hrli 17,-0400
        movei 1,__req
        pushj 17,proc_swap_exchange_records_v786
        jumpn 1,fail1
        hrrz 1,__a+1
        jumpn 1,fail2
        hrrz 1,__b+1
        caie 1,02000
        jrst fail3
        move 1,__ar
        came 1,[012,,3]
        jrst fail4
        move 1,__br
        caie 1,01234
        jrst fail5
        movei 1,__req
        pushj 17,proc_swap_exchange_records_v786
        camn 1,[-1]
        jrst pass
        jrst fail
pass:   setz 1,
        jrst finish
fail1:  movei 1,2
        jrst finish
fail2:  movei 1,3
        jrst finish
fail3:  movei 1,4
        jrst finish
fail4:  movei 1,5
        jrst finish
fail5:  movei 1,6
        jrst finish
fail:   movei 1,1
finish: movem 1,__test_exit
        jrst 4,0
        .data
__req:  .word __a
        .word __b
        .word __ar
        .word __br
        .word 02000
        .word 012
        .word 3
        .word 01234
__a:    .word 0
        .word 04000,,02000
__b:    .word 0
        .word 06000,,0
__ar:   .word 01234
__br:   .word 2,,012
        .bss
        .globl __test_exit
__test_exit: .block 1
__stack: .block 0400
