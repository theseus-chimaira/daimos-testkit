.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; v924: direct noncurrent finish must refuse a
 ; active private kernel-event stack before closing/releasing any VM.
 move 1,[040000,,0]
 iorm 1,__ptable+010
 movei 1,2
 movei 2,2
 pushj 17,proc_finish_slot
 camn 1,[-1]
 jrst v920_finish_refused
 jrst fail_26
v920_finish_refused:
 skipn __vm_calls
 jrst v920_finish_vm_intact
 jrst fail_27
v920_finish_vm_intact:
 skipn __release_calls
 jrst v920_finish_ua_intact
 jrst fail_28
v920_finish_ua_intact:
 move 1,[040000,,0]
 andcam 1,__ptable+010
 move 1,[060000,,0]
 iorm 1,__ptable+010
 movei 1,2
 movei 2,2
 pushj 17,proc_finish_slot
 camn 1,[-1]
 jrst v924_intr_safe
 jrst fail_26
v924_intr_safe:
 skipn __vm_calls
 jrst v924_intr_vm_safe
 jrst fail_28
v924_intr_vm_safe:
 skipn __release_calls
 jrst v924_intr_uarea_safe
 jrst fail_28
v924_intr_uarea_safe:
 move 1,[060000,,0]
 andcam 1,__ptable+010
 ; A VM-destroy failure is NOT a committed HUP. It must still be
 ; reported to the caller, leaving the victim retryable in user mode.
 setom __fail_vm
 movei 1,2
 movei 2,2
 pushj 17,proc_event_apply
 camn 1,[-1]
 jrst check_precommit
 jrst fail_26
check_precommit:
 move 1,__ptable+6
 trne 1,0200000
 jrst fail_27
 move 1,__ptable+7
 camn 1,[04000,,020000]
 jrst precommit_vm_ok
 jrst fail_28
precommit_vm_ok:
 skipn __release_calls
 jrst precommit_release_ok
 jrst fail_29
precommit_release_ok:
 setzm __fail_vm
 ; HUP from a runnable other process. The victim VM is destroyed,
 ; but its pinned u-area cannot yet be freed.
 movei 1,2
 movei 2,2
 pushj 17,proc_event_apply
 jumpe 1,check_committed
 jrst fail_1
check_committed:
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
 move 1,__victim+067
 tlnn 1,0400000
 jrst fail_5
 hrrz 1,__victim+067
 caie 1,0400002
 jrst fail_6
 move 1,__release_calls
 caie 1,1
 jrst fail_7
 move 1,__vm_calls
 caie 1,2
 jrst fail_8
 move 1,__hup_calls
 caie 1,2
 jrst fail_9
 ; Second fatal delivery must not repeat VM/session teardown.
 movei 1,2
 movei 2,2
 pushj 17,proc_event_apply
 camn 1,[-1]
 jrst duplicate_refused
 jrst fail_10
duplicate_refused:
 move 1,__release_calls
 caie 1,1
 jrst fail_11
 ; Background slot-0 finalizer retries once, then commits.
 pushj 17,proc_finish_service_v881
 jumpe 1,pending
 jrst fail_12
pending:
 move 1,__release_calls
 caie 1,2
 jrst fail_13
 skipn __parent_ran
 jrst fail_14
 pushj 17,proc_finish_service_v881
 jumpe 1,finished
 jrst fail_15
finished:
 move 1,__release_calls
 caie 1,3
 jrst fail_16
 move 1,__vm_calls
 caie 1,2
 jrst fail_17
 move 1,__hup_calls
 caie 1,2
 jrst fail_18
 move 1,__runq_calls
 caie 1,1
 jrst fail_19
 move 1,__adopt_calls
 caie 1,1
 jrst fail_20
 move 1,__notify_calls
 caie 1,1
 jrst fail_21
 move 1,__ptable+6
 hlrz 1,1
 caie 1,0400002
 jrst fail_22
 move 1,__ptable+010
 lsh 1,-041
 caie 1,4
 jrst fail_23
 ; A reaper revisit must not double free or re-notify the parent.
 pushj 17,proc_finish_service_v881
 jumpe 1,no_duplicate
 jrst fail_24
no_duplicate:
 move 1,__release_calls
 caie 1,3
 jrst fail_25
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
done: movem 1,__test_exit
 jrst 4,0

.globl file_close_all_at_v865
.globl proc_event_nonfatal
proc_event_nonfatal:
 seto 1,
 popj 17,
.globl kret_neg1
kret_neg1:
 seto 1,
 popj 17,
file_close_all_at_v865:
 aos __close_calls
 setz 1,
 popj 17,
.globl file_close_all
file_close_all:
 setz 1,
 popj 17,
.globl proc_exit_current
proc_exit_current:
 seto 1,
 popj 17,
.globl proc_session_teardown
proc_session_teardown:
 aos __hup_calls
 setz 1,
 popj 17,
.globl vm_space_destroy
vm_space_destroy:
 aos __vm_calls
 skipn __fail_vm
 jrst vm_destroy_ok
 seto 1,
 popj 17,
vm_destroy_ok:
 setom 1(1)
 setz 1,
 popj 17,
.globl proc_uarea_release
proc_uarea_release:
 aos __release_calls
 move 3,__release_calls
 caig 3,2
 jrst release_failed
 move 3,(2)
 andi 3,0377777
 movem 3,(2)
 setz 1,
 popj 17,
release_failed:
 seto 1,
 popj 17,
.globl proc_tty_release_session
proc_tty_release_session:
 aos __tty_calls
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
 setom __parent_ran
 movei 1,1
 popj 17,
; An unpublished RUN may not appear in this committed HUP fixture.
.globl proc_slot_discard
proc_slot_discard:
 movei 1,0777
 popj 17,

.data
.globl kconst_7_7
kconst_7_7: .word 7,,7
.globl proc_high_slot
proc_high_slot: .word 3
.globl proc_table
proc_table: .word __ptable
.globl proc_current_slot
proc_current_slot: .word 1
.globl proc_rt_owner
proc_rt_owner: .word 2
.globl proc_sched_kick
proc_sched_kick: .word 0
.globl proc_finish_last_tick_v881
proc_finish_last_tick_v881: .word 0
__ptable:
 .block 3
 .word __parent,,0400001
 .word 04000,,020000
 .word 0200000,,0
 .word __victim,,0400407
 .word 04000,,020000
 .word 0200000,,0
__parent: .block 070
 .word 0
__victim:
 .block 024
 .word 011
 .block 067-025
 .word 0
 .block 0407-070
 .word 0
__close_calls: .word 0
__release_calls: .word 0
__hup_calls: .word 0
__vm_calls: .word 0
__tty_calls: .word 0
__runq_calls: .word 0
__adopt_calls: .word 0
__notify_calls: .word 0
__parent_ran: .word 1
__fail_vm: .word 0
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
