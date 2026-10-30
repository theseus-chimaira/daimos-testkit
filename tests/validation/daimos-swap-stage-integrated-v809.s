.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; Choose an aligned span inside a deliberately oversized RAM pool.
 movei 4,__ram_pool
 addi 4,0177
 andi 4,0777600
 movem 4,__prepare
 movem 4,__req+1
 move 5,4
 addi 5,0200
 movem 5,__req+2
 setz 6,
init:
 move 1,6
 addi 1,0400
 movem 1,__disk(6)
 move 1,6
 addi 1,01000
 movem 1,0(4)
 aoj 4,
 aoj 6,
 caige 6,0600
 jrst init
 movei 1,__stage
 pushj 17,proc_swap_exchange_stage_v784
 jumpn 1,fail
verify:
 setz 6,
verify_loop:
 move 1,__disk(6)
 move 2,6
 addi 2,01000
 came 1,2
 jrst fail
 move 4,__prepare
 addi 4,0200
 add 4,6
 move 1,(4)
 move 2,6
 addi 2,0400
 came 1,2
 jrst fail
 aoj 6,
 caige 6,0400
 jrst verify_loop
 setz 6,
verify_tail:
 move 1,__disk+0400(6)
 move 2,6
 addi 2,01400
 came 1,2
 jrst fail
 aoj 6,
 caige 6,0200
 jrst verify_tail
 skipn __extensions
 jrst fail
 skipn __releases
 jrst check_reservation
 jrst fail
check_reservation:
 move 1,__prepare+010
 caie 1,1
 jrst fail
 setz 1,
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
__stage: .word __prepare
 .word __req
__prepare: .word __ram_pool
 .word 1
 .word 2
 .word 0600
 .word 0600
 .word 7
 .word 2
 .word 3
 .word 0
__req: .word 7
 .word __ram_pool
 .word __ram_pool+0200
 .word 3
 .word 2
 .word 0
 .word 1
__disk: .block 0600
__ram_pool: .block 01000

.globl fs_block_workspace
fs_block_workspace: .block 0200
.bss
.globl __test_exit
__test_exit: .block 1
__stack: .block 0400

.text
.globl mm_process_grow_pinned
mm_process_grow_pinned:
 setz 1,
 popj 17,
.globl mm_process_shrink_pinned
mm_process_shrink_pinned:
 setz 1,
 popj 17,
.globl backstore_extend
backstore_extend:
 aos __extensions
 setz 1,
 popj 17,
.globl backstore_free
backstore_free:
 aos __releases
 popj 17,
.globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
 halt .

.bss
__extensions: .block 1
__releases: .block 1
