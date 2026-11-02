.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 movei 1,0123
 pushj 17,exit_entry_v993
 camn 1,[-1]
 jrst check_refusal
 jrst fail_1
check_refusal:
 move 1,__close_calls
 caie 1,1
 jrst fail_2
 move 1,__hup_calls
 caie 1,1
 jrst fail_3
 skipn __handoff_calls
 jrst attempt_again
 jrst fail_4
attempt_again:
 movei 1,0123
 pushj 17,exit_entry_v993
 jrst fail_5
handoff:
 move 2,__close_calls
 caie 2,2
 jrst fail_6
 move 2,__hup_calls
 caie 2,2
 jrst fail_7
 movei 1,0
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
done: movem 1,__test_exit
 jrst 4,0
.globl file_close_all
file_close_all:
 aos __close_calls
 setz 1,
 popj 17,
.globl proc_session_teardown
proc_session_teardown:
 aos __hup_calls
 move 1,__hup_calls
 caie 1,1
 jrst accepted
 seto 1,
 popj 17,
accepted:
 setz 1,
 popj 17,
.globl proc_exit_current
proc_exit_current:
 aos __handoff_calls
 jrst handoff
.globl kret_neg1
kret_neg1:
 seto 1,
 popj 17,
.data
.globl proc_current_slot
proc_current_slot: .word 3
.globl file_table
file_table: .word __fdtable
__fdtable: .block 3
__close_calls: .word 0
__hup_calls: .word 0
__handoff_calls: .word 0
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
