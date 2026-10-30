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
 ; Align the shared resident core span before executing v784.
 movei 4,__ram_pool
 addi 4,0177
 andi 4,0777600
 movem 4,__mm_req
 movem 4,__records_req+4
 movem 4,__publish_req+4
 hrrm 4,__a+1
 hrrm 4,mm_extents
 movem 4,__prepare
 movem 4,__pure_req+1
 movem 4,__transfer+1
 move 1,__pure_req
 movem 1,__pure_uarea+0406
 move 5,4
 addi 5,0200
 movem 5,__transfer+2
 setz 6,
init_disk:
 move 1,6
 addi 1,0400
 movem 1,__disk(6)
 move 1,6
 addi 1,01000
 movem 1,0(4)
 aoj 4,
 aoj 6,
 caige 6,0600
 jrst init_disk
 movei 1,__run_req
 pushj 17,proc_swap_exchange_preflight_v791
 jumpn 1,fail_preflight
 movei 1,__run_req
 pushj 17,proc_swap_exchange_live_v794
 jumpn 1,fail_live
 ; Reject inconsistent stable B executable backing before any write.
 setzm __pure_uarea+0406
 movei 1,__run_req
 pushj 17,proc_swap_exchange_run_v790
 camn 1,[-1]
 jrst restore_backing
 jrst fail_live
restore_backing:
 move 1,__pure_req
 movem 1,__pure_uarea+0406
 ; A missing B backing bit must reject before destructive transfer.
 movei 1,0400
 andcam 1,__bitmap
 movei 1,__run_req
 pushj 17,proc_swap_exchange_run_v790
 camn 1,[-1]
 jrst restore_bitmap
 jrst fail_entry
restore_bitmap:
 movei 1,0400
 iorm 1,__bitmap
 movei 1,__run_req
 pushj 17,proc_swap_exchange_run_v790
 jumpn 1,fail_entry
 move 4,__prepare
 setz 6,
check_disk:
 move 1,__disk(6)
 move 2,6
 addi 2,01000
 came 1,2
 jrst fail_disk
 aoj 6,
 caige 6,0400
 jrst check_disk
 move 1,__zero_calls
 caie 1,1
 jrst fault_1
 move 1,__reload_calls
 caie 1,1
 jrst fault_2
 move 5,__prepare
 movei 6,03400
verify_pure:
 move 1,(5)
 movei 2,01234
 came 1,2
 jrst fault_3
 aoj 5,
 sojg 6,verify_pure
 hrrz 1,__a+1
 jumpn 1,fail
 hrrz 1,__b+1
 came 1,__prepare
 jrst fault_4
 move 1,__a_record
 came 1,[010,,3]
 jrst fault_5
 move 1,__b_record
 came 1,__pure_req
 jrst fault_6
 move 1,backstore_blocks_used
 caie 1,3
 jrst fault_7
 move 1,__bitmap
 andi 1,07777
 caie 1,03400
 jrst fault_8
 move 1,proc_swap_blocks_used
 caie 1,5
 jrst fault_9
 move 1,__a
 trne 1,0200000
 jrst fault_10
 move 1,__b
 trne 1,0200000
 jrst fault_11
 move 1,mm_extents+1
 hrrz 2,1
 caie 2,2
 jrst fault_12
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
fail_entry: movei 1,2
 jrst done
fail_preflight: movei 1,5
 jrst done
fail_live: movei 1,6
 jrst done
fail_disk: movei 1,3
 jrst done
fail_ram: movei 1,4
 jrst done
fail: movei 1,1
done: movem 1,__test_exit
 jrst 4,0
.globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
 halt .
.data
__run_req: .word __stage_req
 .word __commit_req
__stage_req: .word __prepare
 .word __transfer
__prepare: .word __ram_pool
 .word 1
 .word 2
 .word 04000
 .word 04000
 .word 010
 .word 2
 .word 3
 .word 0
__transfer: .word 010
 .word __ram_pool
 .word __ram_pool+0200
 .word 3
 .word 2
 .word 0
 .word 1
__commit_req: .word __prepare
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
__pure_req: .word 070000001234
 .word __pure_ram
 .word __pure_uarea
 .word 03400
__records_req: .word __a
 .word __b
 .word __a_record
 .word __b_record
 .word 02000
 .word 010
 .word 3
 .word 070000001234
__account_req: .word 010
 .word 2
 .word 3
 .word 0
__publish_req: .word __a
 .word __b
 .word 1
 .word 2
 .word 02000
__a: .word 0200000
 .word 04000,,02000
__b: .word __pure_uarea,,0600000
 .word 04000,,0
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
.globl backstore_enabled
backstore_enabled: .word 1
.globl backstore_blocks_used
backstore_blocks_used: .word 2
.globl backstore_bitmap
backstore_bitmap: .word __bitmap
__bitmap: .word 01400
 .data
__pure_ram: .block 0200
__pure_uarea: .block 0410
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
 move 4,__pure_req
 came 1,4
 jrst reload_fail
 move 4,__prepare
 came 2,4
 jrst reload_fail
 movei 4,__pure_uarea
 came 3,4
 jrst reload_fail
 move 4,__prepare
 movei 5,03400
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

.text

.data
__disk: .block 0600
__ram_pool: .block 05000
.globl fs_block_workspace
fs_block_workspace: .block 0200
.text
.globl bcache_workspace_invalidate
bcache_workspace_invalidate:
 popj 17,
.globl backstore_read
backstore_read:
 move 4,1
 subi 4,010
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
 subi 4,010
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
.globl mm_process_grow_pinned
mm_process_grow_pinned:
 setz 1,
 popj 17,

fault_1: movei 1,11
 jrst done
fault_2: movei 1,12
 jrst done
fault_3: movei 1,13
 jrst done
fault_4: movei 1,14
 jrst done
fault_5: movei 1,15
 jrst done
fault_6: movei 1,16
 jrst done
fault_7: movei 1,17
 jrst done
fault_8: movei 1,020
 jrst done
fault_9: movei 1,021
 jrst done
fault_10: movei 1,022
 jrst done
fault_11: movei 1,023
 jrst done
fault_12: movei 1,024
 jrst done
