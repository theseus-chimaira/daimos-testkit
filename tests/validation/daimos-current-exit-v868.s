.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; Current-process fatal event: first FD sync fails, second is closed.
 movei 1,3
 movei 2,1
 pushj 17,proc_event_apply
 camn 1,[-1]
 jrst event_failed
 jrst fail_1
event_failed:
 move 1,__caller
 camn 1,[020002000001]
 jrst event_fd_retained
 jrst fail_2
event_fd_retained:
 skipn __caller+2
 jrst event_fd2_closed
 jrst fail_3
event_fd2_closed:
 skipn __exit_calls
 jrst event_retry
 jrst fail_4
event_retry:
 setzm __inject_failure
 movei 1,3
 movei 2,1
 pushj 17,proc_event_apply
 jumpe 1,event_finished
 jrst fail_5
event_finished:
 move 1,__exit_calls
 caie 1,1
 jrst fail_6
 move 1,__exit_status
 camn 1,[0400001]
 jrst event_status_ok
 jrst fail_7
event_status_ok:
 skipn __caller
 jrst exit_failure
 jrst fail_8
exit_failure:
 ; A direct SYS_EXIT failure must leave the current process alive.
 move 1,[020002000001]
 movem 1,__caller
 movei 1,1
 movem 1,__inject_failure
 movei 1,0123
 pushj 17,native_sys_exit_v868
 camn 1,[-1]
 jrst exit_fd_retained
 jrst fail_9
exit_fd_retained:
 move 1,__caller
 camn 1,[020002000001]
 jrst exit_still_alive
 jrst fail_10
exit_still_alive:
 move 1,__exit_calls
 caie 1,1
 jrst fail_11
 ; The second exit attempt commits after the provider recovers.
 setzm __inject_failure
 movei 1,0123
 pushj 17,native_sys_exit_v868
 jumpe 1,exit_finished
 jrst fail_12
exit_finished:
 move 1,__exit_calls
 caie 1,2
 jrst fail_13
 move 1,__exit_status
 caie 1,0123
 jrst fail_14
 skipn __caller
 jrst pass
 jrst fail_15
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
done: movem 1,__test_exit
 jrst 4,0

; Successful terminal EXIT is instrumented; production does not return.
.globl proc_exit_current
proc_exit_current:
 aos __exit_calls
 movem 1,__exit_status
 setz 1,
 popj 17,
.globl proc_finish_slot
proc_finish_slot:
 seto 1,
 popj 17,
.globl proc_event_nonfatal
proc_event_nonfatal:
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
.data
.globl file_table
file_table: .word __caller
__caller: .word 020002000001
 .word 0
 .word 020002000002
 .block 035
__inject_failure: .word 1
__sync_calls: .word 0
__exit_calls: .word 0
__exit_status: .word 0
.globl proc_table
proc_table: .word __ptable
.globl proc_current_slot
proc_current_slot: .word 3
__ptable: .block 011
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
