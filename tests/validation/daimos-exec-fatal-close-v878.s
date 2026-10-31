.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; Fatal EXEC: first close succeeds. No FD may reach process exit alive.
 movni 2,2
 movem 2,__exec_result
 setzm __fail_close
 movei 2,__launch
 pushj 17,native_sys_exec
 move 1,__close_calls
 caie 1,1
 jrst fail_1
 move 1,__exit_calls
 caie 1,1
 jrst fail_2
 skipn __fd
 jrst check_exit_status
 jrst fail_3
check_exit_status:
 move 1,__exit_status
 caie 1,1
 jrst fail_4
 ; A failed close must retain its FILE until a timer yield and retry.
 movni 2,2
 movem 2,__exec_result
 movei 2,1
 movem 2,__fail_close
 movei 3,01234567
 movem 3,__fd
 movei 2,__launch
 pushj 17,native_sys_exec
 move 1,__close_calls
 caie 1,3
 jrst fail_5
 move 1,__exit_calls
 caie 1,2
 jrst fail_6
 skipn __fd
 jrst check_retry_sleep
 jrst fail_7
check_retry_sleep:
 move 1,__sleep_calls
 caie 1,1
 jrst fail_7
 skipn __retry_fd_held
 jrst fail_7
 ; A recoverable pre-commit error must not close or exit.
 setzm __fail_close
 setom __exec_result
 movei 2,__launch
 pushj 17,native_sys_exec
 camn 1,[-1]
 jrst check_precommit
 jrst fail_8
check_precommit:
 move 1,__close_calls
 caie 1,3
 jrst fail_9
 move 1,__exit_calls
 caie 1,2
 jrst fail_10
 ; Committed EXEC success must enter the new image without FILE close.
 setzm __exec_result
 movei 2,__launch
 pushj 17,native_sys_exec
 move 1,__enter_calls
 caie 1,1
 jrst fail_11
 move 1,__close_calls
 caie 1,3
 jrst fail_12
 ; Bad initial mapping must not touch FILE resources either.
 movei 1,1
 movem 1,__fail_map
 movei 2,__launch
 pushj 17,native_sys_exec
 camn 1,[-1]
 jrst check_bad_map
 jrst fail_13
check_bad_map:
 move 1,__close_calls
 caie 1,3
 jrst fail_14
 move 1,__exit_calls
 caie 1,2
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

.globl native_sys_map_one
native_sys_map_one:
 skipn __fail_map
 jrst map_ok
 setz 1,
 popj 17,
map_ok:
 move 1,2
 movei 3,0
 movei 4,020
 popj 17,

.globl exec_replace_current
exec_replace_current:
 move 1,__exec_result
 popj 17,

.globl file_close_all
file_close_all:
 aos __close_calls
 skipn __fail_close
 jrst close_success
 seto 1,
 popj 17,

.globl proc_sleep_ticks
proc_sleep_ticks:
 aos __sleep_calls
 move 2,__fd
 caie 2,01234567
 jrst sleep_bad
 setom __retry_fd_held
 setzm __fail_close
 setz 1,
 popj 17,
sleep_bad:
 seto 1,
 popj 17,
close_success:
 setzm __fd
 setz 1,
 popj 17,

.globl proc_exit_current
proc_exit_current:
 aos __exit_calls
 movem 1,__exit_status
 popj 17,

.globl proc_exec_enter
proc_exec_enter:
 aos __enter_calls
 popj 17,

.globl native_sys_mapped_return
native_sys_mapped_return:
 popj 17,

.globl kret_neg1
kret_neg1: seto 1,
 popj 17,

.data
.globl file_table
file_table: .word __uarea+026
.globl proc_current_slot
proc_current_slot: .word 2
__uarea: .block 026
__fd: .word 01234567
.block 0410-027
__launch: .block 020
__exec_result: .word -2
__fail_close: .word 0
__fail_map: .word 0
__close_calls: .word 0
__exit_calls: .word 0
__exit_status: .word 0
__enter_calls: .word 0
__sleep_calls: .word 0
__retry_fd_held: .word 0
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
