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
 movem 1,__ram(6)
 aoj 6,
 caige 6,0600
 jrst init
 movei 1,__req
 pushj 17,proc_swap_exchange_transfer_v774
 jumpn 1,fail_transfer
 setz 6,
check:
 move 1,__disk(6)
 move 2,6
 addi 2,01000
 came 1,2
 jrst fail_disk
 move 1,__ram+0200(6)
 move 2,6
 addi 2,0400
 came 1,2
 jrst fail_ram
 aoj 6,
 caige 6,0400
 jrst check
 setz 6,
check_tail:
 move 1,__disk+0400(6)
 move 2,6
 addi 2,01400
 came 1,2
 jrst fail
 aoj 6,
 caige 6,0200
 jrst check_tail
 ; Repeat with smaller outgoing A and larger incoming B.
 setz 6,
init_second:
 move 1,6
 addi 1,0400
 movem 1,__disk(6)
 move 1,6
 addi 1,01000
 movem 1,__ram(6)
 aoj 6,
 caige 6,0600
 jrst init_second
 movei 1,2
 movem 1,__req+3
 movei 1,3
 movem 1,__req+4
 movei 1,__req
 pushj 17,proc_swap_exchange_transfer_v774
 jumpn 1,fail_transfer
 setz 6,
check_second:
 move 1,__ram+0200(6)
 move 2,6
 addi 2,0400
 came 1,2
 jrst fail_ram
 aoj 6,
 caige 6,0600
 jrst check_second
 setz 6,
check_second_disk:
 move 1,__disk(6)
 move 2,6
 addi 2,01000
 came 1,2
 jrst fail_disk
 aoj 6,
 caige 6,0400
 jrst check_second_disk
 setz 1,
 jrst done
fail_transfer: movei 1,2
 jrst done
fail_disk: movei 1,3
 jrst done
fail_ram: movei 1,4
 jrst done
fail: movei 1,1
done: movem 1,__test_exit
 jrst 4,0
.globl bcache_workspace_invalidate
bcache_workspace_invalidate:
 popj 17,
.globl backstore_read
backstore_read:
 move 4,1
 subi 4,7
 lsh 4,7
 addi 4,__disk
 hrli 4,0(4)
 hrr 4,3
 move 5,3
 addi 5,0177
 blt 4,0(5)
 setz 1,
 popj 17,
.globl backstore_write
backstore_write:
 move 4,1
 subi 4,7
 lsh 4,7
 addi 4,__disk
 move 5,3
 hrli 5,0(3)
 hrr 5,4
 move 6,4
 addi 6,0177
 blt 5,0(6)
 setz 1,
 popj 17,
.data
__req: .word 7
 .word __ram
 .word __ram+0200
 .word 3
 .word 2
 .word 0
 .word 1
__disk: .block 0600
__ram: .block 0600

.globl fs_block_workspace
fs_block_workspace: .block 0200
.bss
.globl __test_exit
__test_exit: .block 1
__stack: .block 0400
