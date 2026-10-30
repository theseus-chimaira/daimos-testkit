.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 movei 5,__pure_ram
 movei 6,0200
init_pure:
 movei 1,0777
 movem 1,(5)
 aoj 5,
 sojg 6,init_pure
 movei 1,__commit_req
 pushj 17,proc_swap_exchange_commit_v789
 jumpn 1,fail
 move 1,__zero_calls
 caie 1,1
 jrst fail
 move 1,__reload_calls
 caie 1,1
 jrst fail
 movei 5,__pure_ram
 movei 6,0200
verify_pure:
 move 1,(5)
 movei 2,01234
 came 1,2
 jrst fail
 aoj 5,
 sojg 6,verify_pure
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
 .word __pure_ram
 .word __pure_uarea
 .word 0200
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
 .data
__pure_ram: .block 0200
__pure_uarea: .word 0
.bss
__zero_calls: .block 1
__reload_calls: .block 1
.text
.globl fs_zero_words
fs_zero_words:
 aos __zero_calls
 move 4,1
 move 5,2
zero_prefix:
 setzm (4)
 aoj 4,
 sojg 5,zero_prefix
 setz 1,
 popj 17,
.globl proc_swap_reload_pure
proc_swap_reload_pure:
 aos __reload_calls
 movei 4,01234
 came 1,4
 jrst reload_fail
 movei 4,__pure_ram
 came 2,4
 jrst reload_fail
 movei 4,__pure_uarea
 came 3,4
 jrst reload_fail
 movei 4,__pure_ram
 movei 5,0200
reload_prefix:
 skipn (4)
 jrst reload_next
 jrst reload_fail
reload_next:
 movei 6,01234
 movem 6,(4)
 aoj 4,
 sojg 5,reload_prefix
 setz 1,
 popj 17,
reload_fail:
 seto 1,
 popj 17,
