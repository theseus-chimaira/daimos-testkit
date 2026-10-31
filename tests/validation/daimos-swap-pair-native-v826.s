.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 movei 6,1
 movei 1,1
 movei 2,2
 pushj 17,proc_swap_exchange_pair_v826
 jumpn 1,fail
 ; v828: never choose the currently executing process.
 movei 6,2
 movei 3,1
 movem 3,proc_current_slot
 movei 1,1
 movei 2,2
 pushj 17,proc_swap_exchange_pair_v826
 camn 1,[-1]
 jrst restore_current_v828
 jrst fail
restore_current_v828:
 setzm proc_current_slot
 ; v828: an active user map is not exchangeable.
 movei 6,3
 movei 3,2
 movem 3,__a_uarea+024
 movei 1,1
 movei 2,2
 pushj 17,proc_swap_exchange_pair_v826
 camn 1,[-1]
 jrst restore_map_v828
 jrst fail
restore_map_v828:
 setzm __a_uarea+024
 movei 6,5
 movei 3,1
 movem 3,__pin_fixture
 movei 1,1
 movei 2,2
 pushj 17,proc_swap_exchange_pair_v826
 camn 1,[-1]
 jrst restore_pin_v828
 jrst fail
restore_pin_v828:
 setzm __pin_fixture
 movei 6,4
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
fail: move 1,6
done: movem 1,__test_exit
 jrst 4,0
.data
.globl proc_high_slot
proc_high_slot: .word 3
.globl proc_current_slot
proc_current_slot: .word 0
.globl proc_table
proc_table: .word __table
__table: .block 3
__a: .word __a_uarea,,0400000
 .word 064000,,02000
 .word 0300000,,0
__b: .word __uarea,,0400000
 .word 064000,,0
 .word 0200000,,0
.globl proc_swap_records
proc_swap_records: .word __records
__pin_fixture: .word 0
__records: .word 0
 .word 037
__rec: .word 020,,0320
__a_uarea: .block 0407
__uarea: .block 0406
 .word 037
.bss
.globl __test_exit
__test_exit: .block 1
__stack: .block 0400
.text
.globl mm_is_pinned
mm_is_pinned:
 move 1,__pin_fixture
 popj 17,
