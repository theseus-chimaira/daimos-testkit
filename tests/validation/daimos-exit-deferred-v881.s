.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; A tagged post-VM u-area owner must hand control to slot 0, not HALT.
 movei 1,2
 movem 1,proc_current_slot
 setzm __success
 movei 1,012345
 pushj 17,proc_exit_finish
 caie 1,1
 jrst fail_1
 skipn proc_current_slot
 jrst check_pending
 jrst fail_2
check_pending:
 move 1,__status_seen
 caie 1,012345
 jrst fail_3
 ; Failure without tag must still be reported as unrecoverable.
 setzm __uarea+067
 movei 1,2
 movem 1,proc_current_slot
 movei 1,017
 pushj 17,proc_exit_finish
 camn 1,[-1]
 jrst check_bad
 jrst fail_4
check_bad:
 move 1,__status_seen
 caie 1,017
 jrst fail_5
 ; A completed EXIT still reports the normal live-process result.
 movei 1,1
 movem 1,__success
 movei 1,2
 movem 1,proc_current_slot
 movei 1,033
 pushj 17,proc_exit_finish
 jumpe 1,check_success
 jrst fail_6
check_success:
 move 1,__live_calls
 caie 1,1
 jrst fail_7
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
done: movem 1,__test_exit
 jrst 4,0
.globl proc_finish_slot
proc_finish_slot:
 movem 2,__status_seen
 skipn __success
 jrst fake_fail
 setz 1,
 popj 17,
fake_fail:
 seto 1,
 popj 17,
.globl proc_has_live_user
proc_has_live_user:
 aos __live_calls
 setz 1,
 popj 17,
.data
.globl proc_table
proc_table: .word __ptable
.globl proc_current_slot
proc_current_slot: .word 2
.globl proc_current_ptr
proc_current_ptr: .word __ptable+6
__ptable: .block 6
 .word __uarea,,0600000
 .word -1
 .word 0200000,,0
__uarea: .block 024
 .word 011
 .block 067-025
 .word 0400000,,012345
 .block 0410-070
__status_seen: .word 0
__success: .word 0
__live_calls: .word 0
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
