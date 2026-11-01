.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; An unowned TTY with a retained line must not be transferred.
 movei 1,1
 movem 1,__blocked
 movem 1,__line_live
 movei 2,0
 movei 3,1
 movei 4,__proc
 pushj 17,proc_control_tty_attach
 camn 1,[-1]
 jrst check_attach_rejected
 jrst fail_1
check_attach_rejected:
 move 1,proc_tty_records
 camn 1,[040000000000]       ; output routing must not change
 jrst check_no_session
 jrst fail_2
check_no_session:
 skipn __session_updates
 jrst check_attempts
 jrst fail_3
check_attempts:
 move 1,__reset_calls
 caie 1,1
 jrst fail_4
 ; Once the provider succeeds, the next claim must retire the line,
 ; preserve the original route and publish the new session exactly once.
 setzm __blocked
 movei 2,0
 movei 3,1
 movei 4,__proc
 pushj 17,proc_control_tty_attach
 jumpe 1,check_attach_committed
 jrst fail_5
check_attach_committed:
 move 1,proc_tty_records
 and 1,[174000000000]
 camn 1,[040000000000]       ; preserve high route through helper call
 jrst check_route
 jrst fail_6
check_route:
 skipn __line_live
 jrst check_attached_session
 jrst fail_7
check_attached_session:
 move 1,__session_updates
 caie 1,1
 jrst fail_8
 move 1,__new_state
 caie 1,2
 jrst fail_9
 ; Simulate a pinned canonical line on explicit DETACH. Its session
 ; must remain attached until the exact MM extent becomes releasable.
 movei 1,1
 movem 1,__blocked
 movem 1,__line_live
 movei 2,0
 movei 3,1
 pushj 17,proc_control_tty_detach
 camn 1,[-1]
 jrst check_detach_rejected
 jrst fail_10
check_detach_rejected:
 skipn proc_tty_records
 jrst fail_11
 move 1,__session_updates
 caie 1,1
 jrst fail_12
 ; Unpin and retry; only now does the original TTY session detach.
 setzm __blocked
 movei 2,0
 movei 3,1
 pushj 17,proc_control_tty_detach
 jumpe 1,check_detach_committed
 jrst fail_13
check_detach_committed:
 move 1,proc_tty_records
 camn 1,[040000000000]       ; detach only clears the session
 jrst check_released_line
 jrst fail_14
check_released_line:
 skipn __line_live
 jrst check_detach_state
 jrst fail_15
check_detach_state:
 move 1,__session_updates
 caie 1,2
 jrst fail_16
 move 1,__new_state
 caie 1,1
 jrst fail_17
 move 1,__reset_calls
 caie 1,4
 jrst fail_18
 setz 1,
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
done: movem 1,__test_exit
 jrst 4,0

 ; Compatibility for the pre-v897 negative control: its unchecked
 ; reset entry returns void, intentionally discarding the MM error.
.globl proc_tty_line_reset
proc_tty_line_reset:
 pushj 17,proc_tty_line_try_reset_v897
 popj 17,

; The test helper models the exact ownership contract of the real C
; wrapper: a failed mm_free keeps a nonzero line base and returns -1.
.globl proc_tty_line_try_reset_v897
proc_tty_line_try_reset_v897:
 aos __reset_calls
 jumpe 1,try_valid
 jrst bad_tty
try_valid:
 skipn __blocked
 jrst reset_line
 seto 1,
 popj 17,
reset_line:
 setzm __line_live
 setz 1,
 popj 17,
bad_tty:
 seto 1,
 popj 17,

; The caller already validated the owner in the real TTY selector.
.globl proc_control_tty_owned
proc_control_tty_owned:
 movei 1,0
 movei 5,1
 popj 17,
.globl proc_tty_set_session_state
proc_tty_set_session_state:
 aos __session_updates
 movem 1,__session
 movem 2,__new_state
 popj 17,
.globl kret_neg1
kret_neg1: seto 1,
 popj 17,
.globl kret_zero
kret_zero: setz 1,
 popj 17,

.data
.globl proc_tty_records
proc_tty_records: .word 040000000000
                  .block 024
__proc: .word __uarea,,1
__uarea: .block 024
         .word 010                   ; session 1 in FDCTL bits 3..10
__blocked: .word 0
__line_live: .word 0
__reset_calls: .word 0
__session_updates: .word 0
__session: .word 0
__new_state: .word 0
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
