; v1102: the active slot-0 retry scan must retain the shared pending bit.
; Actual production service, mark_pending and backoff leaves are linked.
.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 movei 1,1
 pushj 17,proc_finish_service_v881
 jumpe 1,v1102_first_pending
 jrst v1102_fail_1
v1102_first_pending:
 move 1,proc_finish_last_tick_v881
 camn 1,[0400020,,02000]
 jrst v1102_first_advance
 jrst v1102_fail_2
v1102_first_advance:
 pushj 17,proc_finish_backoff_advance_v885
 move 1,proc_finish_last_tick_v881
 camn 1,[0400040,,02000]
 jrst v1102_second_retry
 jrst v1102_fail_3
v1102_second_retry:
 pushj 17,proc_finish_service_v881
 jumpe 1,v1102_second_pending
 jrst v1102_fail_4
v1102_second_pending:
 move 1,proc_finish_last_tick_v881
 camn 1,[0400040,,02000]
 jrst v1102_second_advance
 jrst v1102_fail_5
v1102_second_advance:
 pushj 17,proc_finish_backoff_advance_v885
 move 1,proc_finish_last_tick_v881
 camn 1,[0400100,,02000]
 jrst v1102_success_retry
 jrst v1102_fail_6
v1102_success_retry:
 pushj 17,proc_finish_service_v881
 jumpe 1,v1102_check_clear
 jrst v1102_fail_7
v1102_check_clear:
 move 1,proc_finish_last_tick_v881
 camn 1,[0100,,02000]
 jrst v1102_final_advance
 jrst v1102_fail_8
v1102_final_advance:
 pushj 17,proc_finish_backoff_advance_v885
 move 1,proc_finish_last_tick_v881
 caie 1,02000
 jrst v1102_fail_9
 move 1,__calls
 caie 1,3
 jrst v1102_fail_10
 skipn __ptable+3
 jrst v1102_pass
 jrst v1102_fail_11
v1102_pass:
 setz 1,
 jrst v1102_done
v1102_fail_1: movei 1,1
 jrst v1102_done
v1102_fail_2: movei 1,2
 jrst v1102_done
v1102_fail_3: movei 1,3
 jrst v1102_done
v1102_fail_4: movei 1,4
 jrst v1102_done
v1102_fail_5: movei 1,5
 jrst v1102_done
v1102_fail_6: movei 1,6
 jrst v1102_done
v1102_fail_7: movei 1,7
 jrst v1102_done
v1102_fail_8: movei 1,010
 jrst v1102_done
v1102_fail_9: movei 1,011
 jrst v1102_done
v1102_fail_10: movei 1,012
 jrst v1102_done
v1102_fail_11: movei 1,013
v1102_done:
 movem 1,__test_exit
 jrst 4,0

.globl proc_finish_slot
proc_finish_slot:
 aos __calls
 move 1,__calls
 caig 1,2
 jrst v1102_refuse
 setzm __ptable+3
 setzm __uarea+067
 setz 1,
 popj 17,
v1102_refuse:
 movei 3,__uarea
 move 4,__uarea+067
 pushj 17,proc_finish_mark_pending_v892
 movni 1,4
 popj 17,
.globl proc_slot_discard
proc_slot_discard:
 movei 1,0777
 popj 17,
.globl proc_has_live_user
proc_has_live_user:
 movei 1,1
 popj 17,

.data
.globl proc_table
proc_table: .word __ptable
.globl proc_high_slot
proc_high_slot: .word 2
.globl proc_sched_kick
proc_sched_kick: .word 0
.globl proc_finish_last_tick_v881
proc_finish_last_tick_v881: .word 0400020,,02000
.globl proc_timer_clock
proc_timer_clock: .word 02000
__ptable:
 .block 3
 .word __uarea,,0600000
 .word -1
 .word 0400000,,0
__uarea: .block 067
 .word 0400000,,01234
__calls: .word 0
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
