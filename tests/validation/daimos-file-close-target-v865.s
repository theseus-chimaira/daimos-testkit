.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 move 1,[010000,,0]      ; saved user-mode return for remote victim
 movem 1,__uarea_other+020
 ; Close another process's file table with a provider callback.
 movei 1,__other
 pushj 17,file_close_all_at_v865
 move 1,file_table
 caie 1,__caller
 jrst fail_1
 skipn __other
 jrst other_second
 jrst fail_2
other_second:
 skipn __other+2
 jrst count_two
 jrst fail_3
count_two:
 move 1,__sync_calls
 caie 1,2
 jrst fail_4
 ; Current-process close uses the ordinary file_close_all ABI.
 pushj 17,file_close_all
 skipn __caller
 jrst count_three
 jrst fail_5
count_three:
 move 1,__sync_calls
 caie 1,3
 jrst fail_6
 ; A normal close(fd) must still use the same entry helper.
 movei 1,020002000001
 movem 1,__caller+4
 movei 1,2
 pushj 17,file_close
 jumpn 1,fail_7
 skipn __caller+4
 jrst count_four
 jrst fail_7
count_four:
 move 1,__sync_calls
 caie 1,4
 jrst fail_8
 ; Invalid fd fails without changing either table.
 movei 1,020
 pushj 17,file_close
 camn 1,[-1]
 jrst test_event
 jrst fail_9
test_event:
 ; Real fatal-other dispatch must close the victim table without changing
 ; file_table. Heavy process finalization is instrumented separately.
 movei 1,020002000001
 movem 1,__other
 movei 1,2
 movei 2,1
 pushj 17,proc_event_apply
 jumpn 1,fail_10
 skipn __other
 jrst event_table_closed
 jrst fail_10
event_table_closed:
 move 1,file_table
 caie 1,__caller
 jrst fail_10
 move 1,__finish_calls
 caie 1,1
 jrst fail_10
 move 1,__sync_calls
 caie 1,5
 jrst fail_10
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
done: movem 1,__test_exit
 jrst 4,0

; The nonfatal branch is linked but not exercised here.
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
 movei 1,016
 popj 17,
.globl vfs_sync
vfs_sync:
 aos __sync_calls
 move 2,file_table
 caie 2,__caller
 jrst sync_global_bad
 movei 1,0
 popj 17,
sync_global_bad:
 movei 1,1
 movem 1,__wrong_table
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
 .word 020002000001
 .block 035
__sync_calls: .word 0
__wrong_table: .word 0
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
