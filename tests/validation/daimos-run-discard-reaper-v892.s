.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; Unpublished RUN child slot 2 has a real VM and a stable u-area.
 ; Two failed frees must retain its ownership through a deferred retry.
 movei 1,2
 pushj 17,proc_slot_discard
 camn 1,[-1]
 jrst check_first
 jrst fail_1
check_first:
 move 1,__ptable+6
 trnn 1,0200000
 jrst fail_2
 trnn 1,0400000
 jrst fail_3
 move 1,__ptable+7
 camn 1,[-1]
 jrst check_marker
 jrst fail_4
check_marker:
 move 1,__uarea+067
 hlrz 1,1
 caie 1,0600000
 jrst fail_5
 move 1,proc_finish_last_tick_v881
 tlnn 1,0400000
 jrst fail_6
 move 1,__vm_calls
 caie 1,1
 jrst fail_7
 move 1,__tty_calls
 caie 1,1
 jrst fail_8
 skipn __release_calls
 jrst fail_9
 skipn __hup_calls
 jrst first_retry
 jrst fail_10
first_retry:
 pushj 17,proc_finish_service_v881
 jumpe 1,check_retry
 jrst fail_11
check_retry:
 move 1,__release_calls
 caie 1,2
 jrst fail_12
 move 1,__vm_calls
 caie 1,1
 jrst fail_13
 move 1,__tty_calls
 caie 1,1
 jrst fail_14
 move 1,__uarea+067
 hlrz 1,1
 caie 1,0600000
 jrst fail_15
 ; Successful third free must discard the unpublished child, without
 ; running normal EXIT, HUP, child adoption, or parent WAIT notification.
 pushj 17,proc_finish_service_v881
 jumpe 1,check_complete
 jrst fail_16
check_complete:
 move 1,__release_calls
 caie 1,3
 jrst fail_17
 skipn __ptable+6
 jrst check_vm
 jrst fail_18
check_vm:
 skipn __ptable+7
 jrst check_sched
 jrst fail_19
check_sched:
 skipn __ptable+010
 jrst check_once
 jrst fail_20
check_once:
 move 1,__runq_calls
 caie 1,1
 jrst fail_21
 skipn __notify_calls
 jrst check_adopt
 jrst fail_22
check_adopt:
 skipn __adopt_calls
 jrst check_hup
 jrst fail_23
check_hup:
 skipn __hup_calls
 jrst final_noop
 jrst fail_24
final_noop:
 pushj 17,proc_finish_service_v881
 move 1,__release_calls
 caie 1,3
 jrst fail_25
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
 jrst done
fail_19: movei 1,023
 jrst done
fail_20: movei 1,024
 jrst done
fail_21: movei 1,025
 jrst done
fail_22: movei 1,026
 jrst done
fail_23: movei 1,027
 jrst done
fail_24: movei 1,030
 jrst done
fail_25: movei 1,031
done: movem 1,__test_exit
 jrst 4,0

.globl vm_space_destroy
vm_space_destroy:
 aos __vm_calls
 setom 1(1)
 setz 1,
 popj 17,
.globl proc_scope_id
proc_scope_id:
 setz 1,
 popj 17,
.globl proc_tty_release_session
proc_tty_release_session:
 aos __tty_calls
 popj 17,
.globl proc_uarea_release
proc_uarea_release:
 aos __release_calls
 move 3,__release_calls
 caig 3,2
 jrst release_failed
 hrrz 3,(2)
 andi 3,0377777
 movem 3,(2)
 setz 1,
 popj 17,
release_failed:
 seto 1,
 popj 17,
.globl proc_session_teardown
proc_session_teardown:
 aos __hup_calls
 setz 1,
 popj 17,
.globl proc_runq_remove
proc_runq_remove:
 aos __runq_calls
 popj 17,
.globl proc_adopt_children_pdp6
proc_adopt_children_pdp6:
 aos __adopt_calls
 popj 17,
.globl proc_notify_parent
proc_notify_parent:
 aos __notify_calls
 popj 17,
.globl proc_trim_high
proc_trim_high:
 popj 17,
.globl proc_has_live_user
proc_has_live_user:
 movei 1,1
 popj 17,

.data
.globl kconst_7_7
kconst_7_7: .word 7,,7
.globl proc_high_slot
proc_high_slot: .word 3
.globl proc_table
proc_table: .word __ptable
.globl proc_rt_owner
proc_rt_owner: .word 0
.globl proc_sched_kick
proc_sched_kick: .word 0
.globl proc_finish_last_tick_v881
proc_finish_last_tick_v881: .word 0
__ptable:
 .block 6
 .word __uarea,,0400407
 .word 04000,,020000
 .word 0100024,,0
__uarea: .block 067
 .word 0
 .block 0410-070
__release_calls: .word 0
__hup_calls: .word 0
__vm_calls: .word 0
__tty_calls: .word 0
__runq_calls: .word 0
__adopt_calls: .word 0
__notify_calls: .word 0
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
