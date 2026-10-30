        .text
        .globl main
main:
        movei 17,__stack-1
        hrli 17,-0400
        movei 1,__request
        pushj 17,proc_swap_exchange_transfer_v774
        jumpn 1,fail
        move 1,__disk
        caie 1,0111
        jrst fail1
        move 1,__disk+0200
        caie 1,0222
        jrst fail2
        move 1,__ram+0200
        caie 1,0333
        jrst fail3
        move 1,__ram+0400
        caie 1,0444
        jrst fail4
        setz 1,
        jrst finish
fail:
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
bcache_workspace_invalidate: popj 17,
        .globl backstore_read
backstore_read:
        lsh 1,7
        move 4,__disk(1)
        movem 4,(3)
        setz 1,
        popj 17,
        .globl backstore_write
backstore_write:
        lsh 1,7
        move 4,(3)
        movem 4,__disk(1)
        setz 1,
        popj 17,
        .data
__request:
        .word 0
        .word __ram
        .word __ram+0200
        .word 2
        .word 2
        .word 0
        .word 1
__disk:
        .word 0333
        .block 0177
        .word 0444
__ram:
        .word 0111
        .block 0177
        .word 0222
        .block 0377
        .bss
        .globl fs_block_workspace
fs_block_workspace: .block 0200
        .globl __test_exit
__test_exit: .block 1
__stack: .block 0400
