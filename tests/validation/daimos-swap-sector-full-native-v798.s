.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 setz 6,
init:
 move 1,6
 addi 1,0400
 movem 1,__disk(6)
 move 1,6
 addi 1,01000
 movem 1,__ram_a(6)
 aoj 6,
 caige 6,0200
 jrst init
 movei 1,7
 movei 2,__ram_a
 movei 3,__ram_b
 pushj 17,proc_swap_exchange_sector_v771
 jumpn 1,fail
 setz 6,
check:
 move 1,__disk(6)
 move 2,6
 addi 2,01000
 came 1,2
 jrst fail
 move 1,__ram_b(6)
 move 2,6
 addi 2,0400
 came 1,2
 jrst fail
 aoj 6,
 caige 6,0200
 jrst check
 move 1,__invalidations
 caie 1,1
 jrst fail
 setz 1,
 jrst done
fail: movei 1,1
done: movem 1,__test_exit
 jrst 4,0
.globl bcache_workspace_invalidate
bcache_workspace_invalidate:
 aos __invalidations
 popj 17,
.globl backstore_read
backstore_read:
 movei 4,__disk
 hrli 4,__disk
 hrr 4,3
 blt 4,0177(3)
 setz 1,
 popj 17,
.globl backstore_write
backstore_write:
 move 4,3
 hrli 4,0(3)
 movei 5,__disk
 hrr 4,5
 blt 4,__disk+0177
 setz 1,
 popj 17,
.data
.globl fs_block_workspace
fs_block_workspace: .block 0200
__disk: .block 0200
__ram_a: .block 0200
__ram_b: .block 0200
.bss
.globl __test_exit
__test_exit: .block 1
__invalidations: .block 1
__stack: .block 0400
