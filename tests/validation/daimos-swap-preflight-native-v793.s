.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 movei 1,__run
 pushj 17,proc_swap_exchange_preflight_v791
 jumpn 1,fail
 movei 2,1
 movem 2,__prep+2
 movei 1,__run
 pushj 17,proc_swap_exchange_preflight_v791
 camn 1,[-1]
 jrst restore_slot
 jrst fail
restore_slot:
 movei 2,2
 movem 2,__prep+2
 movei 2,04001
 movem 2,__prep+3
 movei 1,__run
 pushj 17,proc_swap_exchange_preflight_v791
 camn 1,[-1]
 jrst restore_size
 jrst fail
restore_size:
 movei 2,04000
 movem 2,__prep+3
 setzm __prep+6
 movei 1,__run
 pushj 17,proc_swap_exchange_preflight_v791
 camn 1,[-1]
 jrst pass
 jrst fail
pass:
 setz 1,
 jrst done
fail:
 movei 1,1
done:
 movem 1,__test_exit
 jrst 4,0
.data
__run: .word __stage
 .word __commit
__stage: .word __prep
 .word __transfer
__commit: .word __prep
 .word __pure
 .word __records
 .word __account
 .word __publish
__prep: .word 02000
 .word 1
 .word 2
 .word 04000
 .word 06000
 .word 010
 .word 2
 .word 3
 .word 1
__transfer: .word 010
 .word 02000
 .word 02200
 .word 3
 .word 2
 .word 0
 .word 1
__pure: .word 01234
 .word 02000
 .word 03000
 .word 0200
__records: .word 03000
 .word 04000
 .word 05000
 .word 06000
 .word 02000
 .word 010
 .word 3
 .word 01234
__account: .word 010
 .word 2
 .word 3
 .word 1
__publish: .word 03000
 .word 04000
 .word 1
 .word 2
 .word 02000
.bss
.globl __test_exit
__test_exit: .block 1
__stack: .block 0400
.text
.globl mm_process_verify_pinned_v792
mm_process_verify_pinned_v792:
 movei 4,02000
 came 1,4
 jrst bad_mm
 movei 4,1
 came 2,4
 jrst bad_mm
 movei 4,04000
 came 3,4
 jrst bad_mm
 setz 1,
 popj 17,
bad_mm:
 seto 1,
 popj 17,
