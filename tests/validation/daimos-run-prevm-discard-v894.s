.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 move 1,[010000,,0]       ; v925 saved user return
 movem 1,__uarea+020
 ; PID 2 has a VM but no u-area. PID 3 has both. Each destructor
 ; rejects twice without dropping the owner, then succeeds.
 movei 1,2
 pushj 17,proc_slot_discard
 camn 1,[-1]
 jrst first_3
 jrst fail_1
first_3:
 movei 1,3
 pushj 17,proc_slot_discard
 camn 1,[-1]
 jrst check_markers
 jrst fail_2
check_markers:
 move 1,__ptable+010
 trnn 1,02
 jrst fail_3
 move 1,__ptable+013
 trnn 1,02
 jrst fail_4
 move 1,__ptable+6
 trnn 1,0200000
 jrst fail_5
 move 1,__ptable+011
 trnn 1,0200000
 jrst fail_6
 move 1,proc_finish_last_tick_v881
 hlrz 1,1
 caie 1,0400020
 jrst fail_7
 move 1,__vm_2
 caie 1,1
 jrst fail_8
 move 1,__vm_3
 caie 1,1
 jrst fail_9
 ; First reaper pass retries each VM and keeps their ownership.
 pushj 17,proc_finish_service_v881
 jumpe 1,check_first
 jrst fail_10
check_first:
 move 1,__vm_2
 caie 1,2
 jrst fail_11
 move 1,__vm_3
 caie 1,2
 jrst fail_12
 skipn __free_3
 jrst check_second
 jrst fail_13
check_second:
 ; Second pass destroys both VMs. PID 2 frees immediately;
 ; PID 3's first u-area free fails and changes to the v892 marker.
 pushj 17,proc_finish_service_v881
 jumpe 1,check_free_2
 jrst fail_14
check_free_2:
 skipn __ptable+6
 jrst check_postvm_3
 jrst fail_15
check_postvm_3:
 move 1,__ptable+013
 trne 1,02
 jrst fail_16
 move 1,__uarea+067
 hlrz 1,1
 caie 1,0600000
 jrst fail_17
 move 1,__free_3
 caie 1,1
 jrst fail_18
 move 1,__vm_3
 caie 1,3
 jrst fail_19
 ; Third service retries u-area only; no VM or TTY re-entry.
 pushj 17,proc_finish_service_v881
 jumpe 1,check_final
 jrst fail_20
check_final:
 skipn __ptable+011
 jrst check_count
 jrst fail_21
check_count:
 move 1,__vm_2
 caie 1,3
 jrst fail_22
 move 1,__vm_3
 caie 1,3
 jrst fail_23
 move 1,__free_3
 caie 1,2
 jrst fail_24
 move 1,__tty_calls
 ; v1085 checks checked TTY release on every pre-VM retry. The
 ; session scanner makes subsequent checks harmless once detached.
 caie 1,3
 jrst fail_25
 move 1,__runq_calls
 caie 1,2
 jrst fail_26
 skipn __hup_calls
 jrst check_no_events
 jrst fail_27
check_no_events:
 skipn __notify_calls
 jrst check_no_adopt
 jrst fail_28
check_no_adopt:
 skipn __adopt_calls
 jrst check_noop
 jrst fail_29
check_noop:
 pushj 17,proc_finish_service_v881
 move 1,__vm_2
 caie 1,3
 jrst fail_30
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
 jrst done
fail_26: movei 1,032
 jrst done
fail_27: movei 1,033
 jrst done
fail_28: movei 1,034
 jrst done
fail_29: movei 1,035
 jrst done
fail_30: movei 1,036
done: movem 1,__test_exit
 jrst 4,0

.globl vm_space_destroy
vm_space_destroy:
 move 3,2
 caie 3,2
 jrst vm_for_3
 aos __vm_2
 move 3,__vm_2
 caig 3,2
 jrst vm_failed
 setom 1(1)
 setz 1,
 popj 17,
vm_for_3:
 aos __vm_3
 move 3,__vm_3
 caig 3,2
 jrst vm_failed
 setom 1(1)
 setz 1,
 popj 17,
vm_failed:
 seto 1,
 popj 17,
.globl proc_scope_id
proc_scope_id:
 move 2,(1)
 trnn 2,0400000
 jrst scope_none
 movei 1,1
 popj 17,
scope_none:
 setz 1,
 popj 17,
.globl proc_tty_release_session
proc_tty_release_session:
 jumpe 1,tty_done
 aos __tty_calls
tty_done:
 ; Checked TTY release returns 0 on success (since v1081).
 ; The original fixture returned the session ID in AC1 instead.
 setz 1,
 popj 17,
.globl proc_uarea_release
proc_uarea_release:
 move 3,1
 caie 3,3
 jrst no_uarea
 aos __free_3
 move 3,__free_3
 caie 3,1
 jrst free_success
 seto 1,
 popj 17,
free_success:
 hrrz 3,(2)
 andi 3,0377777
 movem 3,(2)
 setz 1,
 popj 17,
no_uarea:
 setz 1,
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
proc_high_slot: .word 4
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
 .word 0,,0407
 .word 04000,,020000
 .word 0100024,,0
 .word __uarea,,0400407
 .word 04000,,020000
 .word 0100024,,0
__uarea: .block 067
 .word 0
 .block 0410-070
__vm_2: .word 0
__vm_3: .word 0
__free_3: .word 0
__tty_calls: .word 0
__runq_calls: .word 0
__hup_calls: .word 0
__notify_calls: .word 0
__adopt_calls: .word 0
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1

; v924 fixture: a foreign process finalizer, not the running slot.
.globl proc_current_slot
proc_current_slot: .word 0
