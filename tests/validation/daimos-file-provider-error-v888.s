.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; Stage 0: two providers reject. First -5, second -1.
 movei 1,__uarea+026
 pushj 17,file_close_all_at_v865
 camn 1,[-1]
 jrst first_close_rejected_v888
 jrst fail_1
first_close_rejected_v888:
 move 3,__uarea+067
 hlrz 4,3
 caie 4,040
 jrst fail_2
 hrre 4,__uarea+067
 camn 4,[-5]
 jrst first_errno_ok_v888
 jrst fail_3
first_errno_ok_v888:
 skipn __uarea+026
 jrst fail_4
 skipn __uarea+034
 jrst fail_5
 movei 2,0401
 pushj 17,proc_control_getteardown_v886
 move 3,1
 lsh 3,-017
 caie 3,5
 jrst fail_6
 ; Stage 1: fd 0 still rejects with -2; fd 3 now closes.
 movei 1,1
 movem 1,__phase
 movei 1,__uarea+026
 pushj 17,file_close_all_at_v865
 camn 1,[-1]
 jrst second_close_rejected_v888
 jrst fail_7
second_close_rejected_v888:
 hlrz 3,__uarea+067
 caie 3,040
 jrst fail_8
 hrre 3,__uarea+067
 camn 3,[-2]
 jrst second_errno_ok_v888
 jrst fail_9
second_errno_ok_v888:
 skipn __uarea+026
 jrst fail_10
 skipn __uarea+034
 jrst pass_second
 jrst fail_11
pass_second:
 movei 2,0401
 pushj 17,proc_control_getteardown_v886
 move 3,1
 lsh 3,-017
 caie 3,2
 jrst fail_12
 ; Stage 2: all providers accept close; stale cause must vanish.
 movei 1,2
 movem 1,__phase
 movei 1,__uarea+026
 pushj 17,file_close_all_at_v865
 jumpn 1,fail_13
 skipn __uarea+026
 jrst check_zero
 jrst fail_14
check_zero:
 skipn __uarea+067
 jrst check_detail_zero
 jrst fail_15
check_detail_zero:
 movei 2,0401
 pushj 17,proc_control_getteardown_v886
 caie 1,010001
 jrst fail_16
 ; A later failure on FD 3 must retain the actual failing FD
 ; rather than falsely attributing the failure to FD 0.
 move 3,[020002000010]
 movem 3,__uarea+034
 movei 1,3
 movem 1,__phase
 movei 1,__uarea+026
 pushj 17,file_close_all_at_v865
 camn 1,[-1]
 jrst check_fd3_witness_v888
 jrst fail_18
check_fd3_witness_v888:
 hlrz 3,__uarea+067
 caie 3,043
 jrst fail_19
 hrre 3,__uarea+067
 camn 3,[-4]
 jrst check_fd3_detail_v888
 jrst fail_20
check_fd3_detail_v888:
 movei 2,0401
 pushj 17,proc_control_getteardown_v886
 move 3,1
 lsh 3,-017
 caie 3,4
 jrst fail_21
 movei 1,4
 movem 1,__phase
 movei 1,__uarea+026
 pushj 17,file_close_all_at_v865
 jumpn 1,fail_22
 ; A nonfatal bulk close must not modify word 067 at all.
 move 3,[012345,,067123]
 movem 3,__uarea+067
 setzm __uarea+024
 move 3,[012345,,02]
 movem 3,__uarea+026
 movei 1,__uarea+026
 pushj 17,file_close_all_at_v865
 move 3,__uarea+067
 camn 3,[012345,,067123]
 jrst pass
 jrst fail_17
pass: setz 1,
 jrst done
fail_1: movei 1,1
 jrst done
fail_2: movei 1,2
 jrst done
fail_3: movei 1,3
 jrst done
fail_4: movei 1,4
 jrst done
fail_5: movei 1,5
 jrst done
fail_6: movei 1,6
 jrst done
fail_7: movei 1,7
 jrst done
fail_8: movei 1,010
 jrst done
fail_9: movei 1,011
 jrst done
fail_10: movei 1,012
 jrst done
fail_11: movei 1,013
 jrst done
fail_12: movei 1,014
 jrst done
fail_13: movei 1,015
 jrst done
fail_14: movei 1,016
 jrst done
fail_15: movei 1,017
 jrst done
fail_16: movei 1,020
 jrst done
fail_17: movei 1,021
 jrst done
fail_18: movei 1,022
 jrst done
fail_19: movei 1,023
 jrst done
fail_20: movei 1,024
 jrst done
fail_21: movei 1,025
 jrst done
fail_22: movei 1,026
done: movem 1,__test_exit
 jrst 4,0
; Mock only the external provider; the actual bulk close and
; query routines above are directly compiled from production.
.globl file_close_entry_v865
file_close_entry_v865:
 caie 1,__uarea+026
 jrst other_fd
 move 3,__phase
 jumpe 3,first_fail
 caie 3,1
 jrst close_ok
 movni 1,2
 popj 17,
first_fail:
 movni 1,5
 popj 17,
other_fd:
 caie 1,__uarea+034
 jrst close_ok
 move 3,__phase
 caie 3,3
 jrst second_phase_v888
 movni 1,4
 popj 17,
second_phase_v888:
 skipn __phase
 jrst second_fail
 jrst close_ok
second_fail:
 seto 1,
 popj 17,
close_ok:
 setzm (1)
 setz 1,
 popj 17,
.globl kret_neg1
kret_neg1: seto 1,
 popj 17,
.globl kret_zero
kret_zero: setz 1,
 popj 17,
.globl kret_one
kret_one: movei 1,1
 popj 17,
.data
.globl proc_table
proc_table: .word __ptable
.globl proc_high_slot
proc_high_slot: .word 2
.globl proc_finish_last_tick_v881
proc_finish_last_tick_v881: .word 0400020,,01234
__ptable:
 .block 3
 .word __uarea,,0400000
 .word 04000,,020000
 .word 0300000,,0
__uarea: .block 024
 .word 4
 .word 0
 .word 070001,,01
 .word 0
 .block 4
 .word 010000,,3
 .word 0
 .block 067-036
 .word 0
 .block 0410-070
__phase: .word 0
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
