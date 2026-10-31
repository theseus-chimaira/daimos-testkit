.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; Failed anonymous final free retains FD and original reader count.
 movei 1,__fd_anon
 pushj 17,file_close_entry_v865
 camn 1,[-1]
 jrst anon_failed
 jrst fail_1
anon_failed:
 move 1,__fd_anon
 camn 1,[0470001,,__pipe_anon]
 jrst anon_fd_held
 jrst fail_2
anon_fd_held:
 move 1,__pipe_anon+3
 camn 1,[1,,0]
 jrst anon_refs_held
 jrst fail_3
anon_refs_held:
 move 1,__mm_calls
 caie 1,1
 jrst fail_4
 setzm __fail_free
 movei 1,__fd_anon
 pushj 17,file_close_entry_v865
 jumpe 1,anon_recovered
 jrst fail_5
anon_recovered:
 skipn __fd_anon
 jrst fifo_fail
 jrst fail_6
fifo_fail:
 movei 1,1
 movem 1,__fail_free
 movei 1,__fd_fifo
 pushj 17,file_close_entry_v865
 camn 1,[-1]
 jrst fifo_failed
 jrst fail_7
fifo_failed:
 move 1,__fd_fifo
 camn 1,[0470001,,__pipe_fifo]
 jrst fifo_fd_held
 jrst fail_8
fifo_fd_held:
 move 1,__pipe_fifo+3
 camn 1,[1,,0]
 jrst fifo_refs_held
 jrst fail_9
fifo_refs_held:
 move 1,pipe_fifo_head
 caie 1,__pipe_fifo
 jrst fail_10
 move 1,__pipe_fifo
 caie 1,__pipe_other
 jrst fail_11
 setzm __fail_free
 movei 1,__fd_fifo
 pushj 17,file_close_entry_v865
 jumpe 1,fifo_recovered
 jrst fail_12
fifo_recovered:
 skipn __fd_fifo
 jrst fifo_head_check
 jrst fail_13
fifo_head_check:
 move 1,pipe_fifo_head
 caie 1,__pipe_other
 jrst fail_14
 skipn __pipe_other
 jrst nonfinal
 jrst fail_15
nonfinal:
 ; Normal non-final close decrements refs and never frees MM.
 movei 1,__fd_live
 pushj 17,file_close_entry_v865
 jumpe 1,nonfinal_closed
 jrst fail_16
nonfinal_closed:
 skipn __fd_live
 jrst nonfinal_refs
 jrst fail_17
nonfinal_refs:
 move 1,__pipe_live+3
 camn 1,[1,,0]
 jrst check_counts
 jrst fail_18
check_counts:
 move 1,__mm_calls
 caie 1,4
 jrst fail_19
 move 1,__signal_calls
 caie 1,1
 jrst fail_20
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

.globl mm_free
mm_free:
 aos __mm_calls
 skipn __fail_free
 jrst mm_ok
 seto 1,
 popj 17,
mm_ok:
 setz 1,
 popj 17,
.globl pipe_signal_event
pipe_signal_event:
 aos __signal_calls
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
.globl vfs_sync
vfs_sync:
 seto 1,
 popj 17,
.data
.globl pipe_fifo_head
pipe_fifo_head: .word __pipe_other
__fd_anon: .word 0470001,,__pipe_anon
__fd_fifo: .word 0470001,,__pipe_fifo
__fd_live: .word 0470001,,__pipe_live
__pipe_anon:
 .word 0
 .word 0
 .word 0
 .word 1,,0
 .block 012
__pipe_other:
 .word __pipe_fifo
 .word 020002000001
 .word 0
 .word 1,,0
 .block 012
__pipe_fifo:
 .word 0
 .word 020002000002
 .word 0
 .word 1,,0
 .block 012
__pipe_live:
 .word 0
 .word 0
 .word 0
 .word 2,,0
 .block 012
__fail_free: .word 1
__mm_calls: .word 0
__signal_calls: .word 0
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
