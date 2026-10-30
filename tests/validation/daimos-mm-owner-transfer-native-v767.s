        .text
        .globl main
main:
        movei 17,__stack-1
        hrli 17,-0400
        movei 1,02000
        movei 2,1
        movei 3,2
        pushj 17,mm_process_transfer_pinned
        jumpn 1,fail
        hrrz 1,mm_extents+1
        caie 1,2
        jrst fail
        move 1,mm_extents+1
        hlrz 1,1
        caie 1,011
        jrst fail
        movei 1,02000
        movei 2,1
        movei 3,3
        pushj 17,mm_process_transfer_pinned
        camn 1,[-4]
        jrst check_busy
        jrst fail
check_busy:
        movei 1,02000
        movei 2,2
        movei 3,3
        pushj 17,mm_process_transfer_pinned
        jumpn 1,fail
        movei 1,02000
        movei 2,3
        movei 3,3
        pushj 17,mm_process_transfer_pinned
        camn 1,[-4]
        jrst pass
        jrst fail
pass:
        setz 1,
        jrst finish
fail:
        movei 1,1
finish:
        movem 1,__test_exit
        jrst 4,0
        .globl mm_find_base
mm_find_base:
        caie 1,02000
        jrst notfound
        setz 1,
        popj 17,
notfound:
        movei 1,1
        popj 17,
        .data
        .globl mm_extents
mm_extents:
        .word 020000,,02000
        .word 011000001
        .globl mm_extent_count
mm_extent_count:
        .word 1
        .bss
        .globl __test_exit
__test_exit: .block 1
__stack: .block 0400
