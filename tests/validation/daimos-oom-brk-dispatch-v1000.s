.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 movei 4,0
 movei 5,0
 ; Successful BRK must not terminate.
 movei 2,020000
 pushj 17,native_sys_brk
 caie 1,024000
 jrst fail
 skipn __fatal_calls
 jrst test_invalid
 jrst fail
test_invalid:
 movei 4,1
 movei 2,020001
 pushj 17,native_sys_brk
 camn 1,[-1]
 jrst test_invalid_count
 jrst fail
test_invalid_count:
 skipn __fatal_calls
 jrst test_fragmented
 jrst fail
test_fragmented:
 movei 4,2
 movei 2,020002
 pushj 17,native_sys_brk
 skipn __fatal_calls
 jrst test_shortage
 jrst fail
test_shortage:
 movei 4,3
 movei 2,020003
 pushj 17,native_sys_brk
 jrst fail
fatal_seen:
 move 1,__fatal_calls
 caie 1,1
 jrst fail
 setz 1,
 jrst done
fail:
 movei 1,1
done:
 movem 1,__test_exit
 jrst 4,0
.globl vm_space_brk_current
vm_space_brk_current:
 caie 4,0
 jrst brk_error
 movei 1,024000
 setz 2,
 popj 17,
brk_error:
 seto 1,
 move 2,4
 caie 2,1
 jrst not_invalid
 movni 2,4
 popj 17,
not_invalid:
 caie 2,2
 jrst is_shortage
 movni 2,2
 popj 17,
is_shortage:
 seto 2,
 popj 17,
.globl proc_fatal_close_current_v879
proc_fatal_close_current_v879:
 aos __fatal_calls
 jrst fatal_seen
.bss
__stack: .block 0400
__fatal_calls: .block 1
.globl __test_exit
__test_exit: .block 1
