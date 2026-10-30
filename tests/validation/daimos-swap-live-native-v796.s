.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 movei 1,__request
 pushj 17,proc_swap_exchange_live_v794
 jumpn 1,fail
 setzm __bitmap
 movei 1,__request
 pushj 17,proc_swap_exchange_live_v794
 camn 1,[-1]
 jrst bitmap_rejected
 jrst fail
bitmap_rejected:
 movei 1,01400
 movem 1,__bitmap
 movei 1,4
 movem 1,__b_record
 movei 1,__request
 pushj 17,proc_swap_exchange_live_v794
 camn 1,[-1]
 jrst restore
 jrst fail
restore:
 move 1,[010,,2]
 movem 1,__b_record
 setzm __b
 movei 1,__request
 pushj 17,proc_swap_exchange_live_v794
 camn 1,[-1]
 jrst pass
 jrst fail
pass: setz 1,
 jrst done
fail: movei 1,1
done: movem 1,__test_exit
 jrst 4,0
.data
__request: .word __stage
 .word __commit
__stage: .word __prepare
 .word 0
__commit: .word 0
 .word 0
 .word __records
__prepare: .word 02000
 .word 1
 .word 2
 .word 04000
 .word 06000
 .word 010
 .word 2
 .word 3
 .word 0
__records: .word __a
 .word __b
 .word 0
 .word __b_record
__a: .word 0200000
 .word 04000,,02000
__b: .word 0200000
 .word 06000,,0
__b_record: .word 010,,2
.globl proc_storage_runtime_v29
proc_storage_runtime_v29: .word __modes
 .word 4
__modes: .word 020
.bss
.globl __test_exit
__test_exit: .block 1
__stack: .block 0400

.data
.globl backstore_bitmap
backstore_bitmap: .word __bitmap
.globl backstore_blocks
backstore_blocks: .word 044
.globl backstore_enabled
backstore_enabled: .word 1
__bitmap: .word 01400
