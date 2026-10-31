.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; Invalid/nonleader state must never touch TTY or signal members.
 movei 1,2
 move 2,__leader_ctl
 pushj 17,proc_session_teardown
 jumpe 1,nonleader_ok
 jrst fail_1
nonleader_ok:
 skipn __hup_calls
 jrst fail_hup
 jrst fail_2
fail_hup:
 ; Second of two member HUPs fails after the first succeeds.
 movei 1,1
 move 2,__leader_ctl
 pushj 17,proc_session_teardown
 camn 1,[-1]
 jrst fail_ret
 jrst fail_3
fail_ret:
 move 1,proc_tty_records+3
 camn 1,[0777777777777]
 jrst fail_tty
 jrst fail_4
fail_tty:
 move 1,__hup_calls
 caie 1,2
 jrst fail_5
 move 1,__last_slot
 caie 1,3
 jrst fail_6
 ; Retry once closing the stuck member can succeed. No early TTY detach.
 setzm __fail_hup
 movei 1,1
 move 2,__leader_ctl
 pushj 17,proc_session_teardown
 jumpe 1,commit_ret
 jrst fail_7
commit_ret:
 move 1,__hup_calls
 caie 1,4
 jrst fail_8
 move 1,proc_tty_records+3
 camn 1,[174000000000]
 jrst committed
 jrst fail_9
committed:
 ; A leader with no TTY attached does not signal/clear the TTY.
 move 1,[0777777777777]
 movem 1,proc_tty_records+3
 movei 1,1
 movei 2,010000000010
 pushj 17,proc_session_teardown
 jumpe 1,not_attached_ok
 jrst fail_10
not_attached_ok:
 move 1,__hup_calls
 caie 1,4
 jrst fail_11
 move 1,proc_tty_records+3
 camn 1,[0777777777777]
 jrst pass
 jrst fail_12
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
done: movem 1,__test_exit
 jrst 4,0

.globl proc_event_apply
proc_event_apply:
 aos __hup_calls
 movem 1,__last_slot
 movei 4,077
 movei 6,0123
 skipn __fail_hup
 jrst event_good
 cain 1,3
 jrst event_bad
event_good:
 setz 1,
 popj 17,
event_bad:
 seto 1,
 popj 17,

.data
.globl proc_table
proc_table: .word __ptable
.globl proc_high_slot
proc_high_slot: .word 5
.globl proc_tty_records
proc_tty_records: .block 3
 .word 0777777777777
 .block 025-4
__leader_ctl: .word 050000000010
__ptable:
 .block 3
 .word __u1,,0400000
 .word 0
 .word 0200000,,0
 .word __u2,,0400000
 .word 0
 .word 0200000,,0
 .word __u3,,0400000
 .word 0
 .word 0200000,,0
 .block 3
__u1: .block 025
__u2: .block 024
 .word 010
__u3: .block 024
 .word 010
__fail_hup: .word 1
__hup_calls: .word 0
__last_slot: .word 0
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
