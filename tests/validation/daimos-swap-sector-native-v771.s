        .text
        .globl main
main:
        movei 17,__stack-1
        hrli 17,-0400
        movei 1,3
        movei 2,__a
        movei 3,__b
        pushj 17,proc_swap_exchange_sector_v771
        jumpn 1,fail0
        move 1,__disk
        caie 1,0123
        jrst fail1
        move 1,__b
        caie 1,0456
        jrst fail2
        move 1,__disk+0177
        caie 1,0123
        jrst fail3
        move 1,__b+0177
        caie 1,0456
        jrst fail4
        setz 1,
        jrst finish
fail0:
        movei 1,1
        jrst finish
fail1:
        movei 1,2
        jrst finish
fail2:
        movei 1,3
        jrst finish
fail3:
        movei 1,4
        jrst finish
fail4:
        movei 1,5
finish:
        movem 1,__test_exit
        jrst 4,0
        .globl bcache_workspace_invalidate
bcache_workspace_invalidate:
        popj 17,
        .globl backstore_read
backstore_read:
        move 4,__disk
        movem 4,(3)
        move 4,__disk+0177
        movem 4,0177(3)
        setz 1,
        popj 17,
        .globl backstore_write
backstore_write:
        move 4,(3)
        movem 4,__disk
        move 4,0177(3)
        movem 4,__disk+0177
        setz 1,
        popj 17,
        .bss
        .globl fs_block_workspace
fs_block_workspace: .block 0200
        .globl __test_exit
__test_exit: .block 1
        .data
__disk: .word 0456
.block 0176
.word 0456
__a: .word 0123
.block 0176
.word 0123
__b: .block 0200
__stack: .block 0400
