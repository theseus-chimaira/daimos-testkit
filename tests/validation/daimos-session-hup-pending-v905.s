.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; Member 2 commits fatal HUP but its u-area MM cleanup is deferred.
 ; Member 3 then fails HUP. No TTY detach is allowed yet.
 movei 1,1
 move 2,__leader_ctl
 pushj 17,proc_session_teardown
 camn 1,[-1]
 jrst first_rejected
 jrst fail_1
first_rejected:
 move 1,proc_tty_records+3
 camn 1,[0777777777777]
 jrst tty_retained
 jrst fail_2
tty_retained:
 move 1,__calls2
 caie 1,1
 jrst fail_3
 move 1,__calls3
 caie 1,1
 jrst fail_4
 move 1,__ptable+6
 trnn 1,0200000
 jrst fail_5
 move 1,__ptable+7
 camn 1,[-1]
 jrst vm_none
 jrst fail_6
vm_none:
 move 1,__u2+067
 tlne 1,0400000
 jrst pending_marker
 jrst fail_7
pending_marker:
 ; Retry must skip the finalized member, rather than calling
 ; proc_event_apply again (which rejects a TRANSITION owner).
 setzm __fail3
 movei 1,1
 move 2,__leader_ctl
 pushj 17,proc_session_teardown
 jumpe 1,retry_committed
 jrst fail_8
retry_committed:
 move 1,__calls2
 caie 1,1
 jrst fail_9
 move 1,__calls3
 caie 1,2
 jrst fail_10
 move 1,proc_tty_records+3
 camn 1,[174000000000]
 jrst tty_committed
 jrst fail_11
tty_committed:
 ; A TRANSITION and FINALIZE marker alone do not prove fatal commit:
 ; VM must be NONE. The next call must be rejected by the live target.
 move 1,[0777777777777]
 movem 1,proc_tty_records+3
 setzm __ptable+7
 movei 1,1
 move 2,__leader_ctl
 pushj 17,proc_session_teardown
 camn 1,[-1]
 jrst nonempty_vm_rejected
 jrst fail_12
nonempty_vm_rejected:
 move 1,__calls2
 caie 1,2
 jrst fail_13
 move 1,proc_tty_records+3
 camn 1,[0777777777777]
 jrst check_missing_marker
 jrst fail_14
check_missing_marker:
 ; VM_NONE alone is also insufficient without the finalize marker.
 setom __ptable+7
 setzm __u2+067
 movei 1,1
 move 2,__leader_ctl
 pushj 17,proc_session_teardown
 camn 1,[-1]
 jrst missing_marker_rejected
 jrst fail_15
missing_marker_rejected:
 move 1,__calls2
 caie 1,3
 jrst fail_16
 move 1,proc_tty_records+3
 camn 1,[0777777777777]
 jrst pass
 jrst fail_17
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
done: movem 1,__test_exit
 jrst 4,0

.globl proc_event_apply
proc_event_apply:
 caie 1,2
 jrst event_slot3
 aos __calls2
 move 4,__calls2
 caie 4,1
 jrst event_failed
 ; Simulate committed fatal-other HUP, whose VM destroy succeeded
 ; but whose u-area MM free returned BUSY and deferred finalization.
 move 4,__ptable+6
 iori 4,0200000
 movem 4,__ptable+6
 setom __ptable+7
 move 4,[0400000,,0]
 movem 4,__u2+067
 setz 1,
 popj 17,
event_slot3:
 caie 1,3
 jrst event_failed
 aos __calls3
 skipn __fail3
 jrst event_ok
event_failed:
 seto 1,
 popj 17,
event_ok:
 setz 1,
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
__u1: .block 070
__u2: .block 024
 .word 010
 .block 067-025
 .word 0
__u3: .block 024
 .word 010
 .block 070-025
__fail3: .word 1
__calls2: .word 0
__calls3: .word 0
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1

; The v905 fixture has no allocated canonical TTY line. A successful
; idempotent reset is the only legitimate result at commit.
.text
.globl proc_tty_line_try_reset_v897
proc_tty_line_try_reset_v897:
 setz 1,
 popj 17,
