        .text
        .globl main
main:
        movei 17,__stack-1
        hrli 17,-0400
        movei 1,02000
        movei 2,1
        movei 3,06000
        pushj 17,mm_process_grow_pinned
        jumpn 1,fail
        hlrz 1,mm_extents
        caie 1,06000
        jrst fail
        movei 1,02000
        movei 2,1
        movei 3,014000
        pushj 17,mm_process_grow_pinned
        camn 1,[-1]
        jrst verify
        jrst fail
verify:
        hlrz 1,mm_extents
        caie 1,06000
        jrst fail
        movei 1,02000
        movei 2,2
        movei 3,010000
        pushj 17,mm_process_grow_pinned
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
        movei 1,2
        popj 17,
        .data
        .globl mm_extents
mm_extents:
        .word 04000,,02000
        .word 011000001
        .word 02000,,012000
        .word 0000000002
        .globl mm_extent_count
mm_extent_count:
        .word 2
        .globl mm_arena_count
mm_arena_count:
        .word 1
        .globl mm_arenas
mm_arenas:
        .word 020000,,0
        .bss
        .globl __test_exit
__test_exit: .block 1
__stack: .block 0400
