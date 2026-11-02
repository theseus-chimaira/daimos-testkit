.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 movei 1,5
 movei 2,1
 pushj 17,proc_tty_release_session
 move 1,proc_tty_records
 andi 1,0377
 caie 1,5
 jrst failed
 move 1,__reset_calls
 caie 1,1
 jrst failed
 setzm __refuse
 movei 1,5
 movei 2,1
 pushj 17,proc_tty_release_session
 move 1,proc_tty_records
 andi 1,0377
 jumpn 1,failed
 move 1,__reset_calls
 caie 1,2
 jrst failed
 setz 1,
 jrst done
failed: movei 1,1
done: movem 1,__test_exit
 jrst 4,0
.globl proc_tty_session_has
proc_tty_session_has:
 setz 1,
 popj 17,
.globl proc_tty_line_reset
proc_tty_line_reset:
 aos __reset_calls
 skipn __refuse
 setzm __base
 popj 17,
.globl proc_tty_line_base_get
proc_tty_line_base_get:
 move 1,__base
 popj 17,
.data
.globl proc_tty_records
proc_tty_records: .word 5
 .block 024
__refuse: .word 1
__base: .word 04000
__reset_calls: .word 0
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
