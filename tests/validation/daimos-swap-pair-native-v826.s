.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 movei 1,1
 movei 2,2
 pushj 17,proc_swap_exchange_pair_v826
 jumpn 1,fail
 ; v827: a non-RUN target must not be admitted.
 movei 3,0300000
 hrlm 3,__b+2
 movei 1,1
 movei 2,2
 pushj 17,proc_swap_exchange_pair_v826
 camn 1,[-1]
 jrst restore_run_v827
 jrst fail
restore_run_v827:
 movei 3,0200000
 hrlm 3,__b+2
 ; A terminating or otherwise invalid victim is not eligible.
 setzm __a+2
 movei 1,1
 movei 2,2
 pushj 17,proc_swap_exchange_pair_v826
 camn 1,[-1]
 jrst restore_a_v827
 jrst fail
restore_a_v827:
 movei 3,0300000
 hrlm 3,__a+2
 ; Wrong sizes are never eligible.
 movei 3,062000
 hrlm 3,__b+1
 movei 1,1
 movei 2,2
 pushj 17,proc_swap_exchange_pair_v826
 camn 1,[-1]
 jrst restore_size
 jrst fail
restore_size:
 movei 3,064000
 hrlm 3,__b+1
 ; Missing B disk record is rejected.
 setzm __rec
 movei 1,1
 movei 2,2
 pushj 17,proc_swap_exchange_pair_v826
 camn 1,[-1]
 jrst pass
 jrst fail
pass: setz 1,
 jrst done
fail: movei 1,1
done: movem 1,__test_exit
 jrst 4,0
.data
.globl proc_high_slot
proc_high_slot: .word 3
.globl proc_table
proc_table: .word __table
__table: .block 3
__a: .word 0400000
 .word 064000,,02000
 .word 0300000,,0
__b: .word __uarea,,0400000
 .word 064000,,0
 .word 0200000,,0
.globl proc_swap_records
proc_swap_records: .word __records
__records: .word 0
 .word 037
__rec: .word 020,,0320
__uarea: .block 0406
 .word 037
.bss
.globl __test_exit
__test_exit: .block 1
__stack: .block 0400
