.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 movei 1,__commit_req
 pushj 17,proc_swap_exchange_commit_v789
 jumpn 1,fail
 hrrz 1,__a+1
 jumpn 1,fail
 hrrz 1,__b+1
 caie 1,02000
 jrst fail
 move 1,__a_record
 came 1,[010,,2]
 jrst fail
 move 1,__b_record
 caie 1,01234
 jrst fail
 move 1,backstore_blocks_used
 caie 1,2
 jrst fail
 move 1,__bitmap
 andi 1,07777
 caie 1,01400
 jrst fail
 move 1,proc_swap_blocks_used
 caie 1,3
 jrst fail
 move 1,__a
 trne 1,0200000
 jrst fail
 move 1,__b
 trne 1,0200000
 jrst fail
 move 1,mm_extents+1
 hrrz 2,1
 caie 2,2
 jrst fail
 and 1,[03770000000]
 jumpn 1,fail
 movei 1,1
 movei 2,1
 pushj 17,proc_storage_expect_v30
 jumpn 1,fail
 movei 1,2
 setz 2,
 pushj 17,proc_storage_expect_v30
 jumpn 1,fail
 setz 1,
 jrst done
fail: movei 1,1
done: movem 1,__test_exit
 jrst 4,0
.globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
 halt .
.data
__commit_req: .word __mm_req
 .word __pure_req
 .word __records_req
 .word __account_req
 .word __publish_req
 .word 0
__mm_req: .word 02000
 .word 1
 .word 2
 .word 04000
 .word 04000
__pure_req: .word 01234
 .word 02000
 .word 0
 .word 0
__records_req: .word __a
 .word __b
 .word __a_record
 .word __b_record
 .word 02000
 .word 010
 .word 2
 .word 01234
__account_req: .word 010
 .word 3
 .word 2
 .word 0
__publish_req: .word __a
 .word __b
 .word 1
 .word 2
 .word 02000
__a: .word 0200000
 .word 04000,,02000
__b: .word 0200000
 .word 06000,,0
__a_record: .word 01234
__b_record: .word 010,,2
.globl proc_swap_blocks_used
proc_swap_blocks_used: .word 4
.globl proc_storage_runtime_v29
proc_storage_runtime_v29: .word __modes
 .word 4
__modes: .word 020
.bss
.globl __test_exit
__test_exit: .block 1

__stack: .block 0400
.data
.globl mm_extent_count
mm_extent_count: .word 1
.globl mm_extents
mm_extents: .word 04000,,02000
 .word 011000001

.data
.globl backstore_blocks
backstore_blocks: .word 044
.globl backstore_blocks_used
backstore_blocks_used: .word 3
.globl backstore_bitmap
backstore_bitmap: .word __bitmap
__bitmap: .word 03400
.text
.globl fs_zero_words
fs_zero_words:
 setz 1,
 popj 17,
.globl proc_swap_reload_pure
proc_swap_reload_pure:
 setz 1,
 popj 17,
