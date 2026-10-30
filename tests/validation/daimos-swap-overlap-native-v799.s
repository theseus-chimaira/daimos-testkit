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
 pushj 17,proc_swap_exchange_overlap_v772
 jumpn 1,fail
 setz 6,
check:
 move 1,__disk(6)
 move 2,6
 addi 2,01000
 came 1,2
 jrst fail
 move 1,__ram+0200(6)
 move 2,6
 addi 2,0400
 came 1,2
 jrst fail
 aoj 6,
 caige 6,0400
 jrst check
 setz 1,
 jrst done
fail: movei 1,1
done: movem 1,__test_exit
 jrst 4,0
.globl proc_swap_exchange_sector_v771
proc_swap_exchange_sector_v771:
 ; AC1 is a disk block, AC2 the source, AC3 the destination.
 move 4,1
 subi 4,7
 lsh 4,7
 addi 4,__disk
 move 5,4
 hrli 5,0(4)
 movei 7,__scratch
 hrr 5,7
 blt 5,__scratch+0177
 move 5,2
 hrli 5,0(2)
 hrr 5,4
 move 7,4
 addi 7,0177
 blt 5,0(7)
 movei 5,__scratch
 hrli 5,__scratch
 hrr 5,3
 move 7,3
 addi 7,0177
 blt 5,0(7)
 setz 1,
 popj 17,
.data
__req: .word 7
 .word __ram
 .word __ram+0200
 .word 2
 .word 0
 .word 1
__disk: .block 0400
__ram: .block 0600
__scratch: .block 0200
.bss
.globl __test_exit
__test_exit: .block 1
__stack: .block 0400
