.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; Failed SYNC is reported but the other descriptor is still closed.
 movei 1,__other
 pushj 17,file_close_all_at_v865
 camn 1,[-1]
 jrst first_failed
 jrst fail_1
first_failed:
 skipn __other
 jrst fail_2
 skipn __other+2
 jrst other_success
 jrst fail_3
other_success:
 move 1,__sync_calls
 caie 1,2
 jrst fail_4
 move 1,file_table
 caie 1,__caller
 jrst fail_5
 ; Fatal event cannot reap a target with an unclosed descriptor.
 movei 1,2
 movei 2,1
 pushj 17,proc_event_apply
 camn 1,[-1]
 jrst fatal_deferred
 jrst fail_6
fatal_deferred:
 skipn __other
 jrst fail_7
 skipn __finish_calls
 jrst allow_retry
 jrst fail_8
allow_retry:
 ; v923: a second failure retries only the surviving FD. The earlier
 ; successful close must not call the provider a second time.
 movei 1,2
 movei 2,1
 pushj 17,proc_event_apply
 camn 1,[-1]
 jrst second_deferred_v923
 jrst fail_14
second_deferred_v923:
 move 1,__sync_calls
 caie 1,4
 jrst fail_15
 skipn __other
 jrst fail_16
 skipn __other+2
 jrst second_ownership_v923
 jrst fail_17
second_ownership_v923:
 skipn __finish_calls
 jrst second_finish_held_v923
 jrst fail_18
second_finish_held_v923:
 move 1,file_table
 caie 1,__caller
 jrst fail_19
 ; The original caller descriptor is not owned by remote cleanup.
 move 1,__caller
 camn 1,[020002000001]
 jrst second_caller_intact_v923
 jrst fail_20
second_caller_intact_v923:
 setzm __inject_failure
 movei 1,2
 movei 2,1
 pushj 17,proc_event_apply
 jumpe 1,finished
 jrst fail_9
finished:
 skipn __other
 jrst test_finish
 jrst fail_10
test_finish:
 move 1,__finish_calls
 caie 1,1
 jrst fail_11
 move 1,__sync_calls
 caie 1,5
 jrst fail_12
 move 1,file_table
 caie 1,__caller
 jrst fail_13
 move 1,__caller
 camn 1,[020002000001]
 jrst pass
 jrst fail_13
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
done: movem 1,__test_exit
 jrst 4,0

; Unused nonfatal dispatch is a separate link-time branch.
.globl proc_event_nonfatal
proc_event_nonfatal:
 seto 1,
 popj 17,
.globl proc_exit_current
proc_exit_current:
 seto 1,
 popj 17,
.globl proc_finish_slot
proc_finish_slot:
 aos __finish_calls
 caie 1,2
 jrst finish_bad
 caie 2,0400001
 jrst finish_bad
 setz 1,
 popj 17,
finish_bad:
 seto 1,
 popj 17,
.globl file_find
file_find:
 caige 1,020
 jrst find_in_range
 setz 1,
 popj 17,
find_in_range:
 lsh 1,1
 add 1,file_table
 skipn (1)
 setz 1,
 popj 17,
.globl file_node_from_fd
file_node_from_fd:
 move 1,(1)
 tlz 1,700070
 popj 17,
.globl kret_neg1
kret_neg1: seto 1,
 popj 17,
.globl kret_zero
kret_zero: setz 1,
 popj 17,
.globl pipe_close_ref
pipe_close_ref:
 seto 1,
 popj 17,
.globl vfs_sync
vfs_sync:
 aos __sync_calls
 move 2,file_table
 caie 2,__caller
 jrst bad_global
 camn 1,[020002000001]
 jrst sync_maybe_fail
 jrst sync_ok
sync_maybe_fail:
 skipn __inject_failure
 jrst sync_ok
 seto 1,
 popj 17,
sync_ok:
 setz 1,
 popj 17,
bad_global:
 seto 1,
 popj 17,
.data
.globl file_table
file_table: .word __caller
__caller: .word 020002000001
 .block 037
__uarea_other: .block 026
__other: .word 020002000001
 .word 0
 .word 020002000002
 .block 035
__inject_failure: .word 1
__sync_calls: .word 0
__finish_calls: .word 0
.globl proc_table
proc_table: .word __ptable
.globl proc_current_slot
proc_current_slot: .word 3
__ptable: .block 6
 .word __uarea_other,,0400000
 .block 2
 .word __uarea_other,,0400000
 .block 2
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
