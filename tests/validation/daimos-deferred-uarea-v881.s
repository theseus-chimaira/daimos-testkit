.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; One unrelated transitioning slot must not enter deferred cleanup.
 movei 1,3
 movei 2,0777
 pushj 17,proc_finish_slot
 camn 1,[-1]
 jrst check_unrelated
 jrst fail_1
check_unrelated:
 skipn __release_calls
 jrst first_exit
 jrst fail_2
first_exit:
 movei 1,2
 movei 2,012345
 pushj 17,proc_finish_slot
 camn 1,[-1]
 jrst check_deferred
 jrst fail_3
check_deferred:
 move 1,__ptable+6
 trnn 1,0200000
 jrst fail_4
 trnn 1,0400000
 jrst fail_5
 move 1,__ptable+7
 camn 1,[-1]
 jrst check_tag
 jrst fail_6
check_tag:
 move 1,__uarea+067
 tlnn 1,0400000
 jrst fail_7
 hrrz 1,__uarea+067
 caie 1,012345
 jrst fail_8
 move 1,__uarea+024
 caie 1,011
 jrst fail_7
 move 1,__release_calls
 caie 1,1
 jrst fail_9
 move 1,__hup_calls
 caie 1,1
 jrst fail_10
 move 1,__vm_calls
 caie 1,1
 jrst fail_11
 skipn proc_rt_owner
 jrst first_retry
 jrst fail_12
first_retry:
 pushj 17,proc_finish_service_v881
 jumpe 1,check_first_retry
 jrst fail_13
check_first_retry:
 move 1,__release_calls
 caie 1,2
 jrst fail_14
 move 1,__hup_calls
 caie 1,1
 jrst fail_15
 move 1,__vm_calls
 caie 1,1
 jrst fail_16
 skipn __runq_calls
 jrst final_retry
 jrst fail_17
final_retry:
 pushj 17,proc_finish_service_v881
 caie 1,1
 jrst fail_18
 move 1,__release_calls
 caie 1,3
 jrst fail_19
 move 1,__hup_calls
 caie 1,1
 jrst fail_20
 move 1,__vm_calls
 caie 1,1
 jrst fail_21
 move 1,__runq_calls
 caie 1,1
 jrst fail_22
 move 1,__adopt_calls
 caie 1,1
 jrst fail_23
 move 1,__notify_calls
 caie 1,1
 jrst fail_24
 move 1,__ptable+6
 hlrz 1,1
 caie 1,012345
 jrst fail_25
 move 1,__ptable+010
 lsh 1,-041
 caie 1,4
 jrst fail_26
 move 1,__ptable+010
 andi 1,0377
 caie 1,1
 jrst fail_26
 ; Repeated idle reaper scan after commit must be a no-op.
 pushj 17,proc_finish_service_v881
 jumpe 1,final_noop
 jrst fail_27
final_noop:
 move 1,__release_calls
 caie 1,3
 jrst fail_28
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
done: movem 1,__test_exit
 jrst 4,0

.globl proc_session_teardown
proc_session_teardown:
 aos __hup_calls
 setz 1,
 popj 17,
.globl vm_space_destroy
vm_space_destroy:
 aos __vm_calls
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
 setz 1,
 popj 17,
; Only v891 unpublished-RUN markers dispatch here. The v881 test
; exercises normal EXIT markers, so any call is a regression.
.globl proc_slot_discard
proc_slot_discard:
 movei 1,0777
 popj 17,

.data
.globl kconst_7_7
kconst_7_7: .word 7,,7
.globl proc_high_slot
proc_high_slot: .word 4
.globl proc_table
proc_table: .word __ptable
.globl proc_rt_owner
proc_rt_owner: .word 2
.globl proc_sched_kick
proc_sched_kick: .word 0
.globl proc_finish_last_tick_v881
proc_finish_last_tick_v881: .word 0
__ptable: .block 6
 .word __uarea,,0400407
 .word 04000,,020000
 .word 0200000,,0
 .word __other,,0600000
 .word 04000,,020000
 .word 0200000,,0
__uarea: .block 024
 .word 011
 .block 067-025
 .word 0
 .block 0407-070
 .word 0
__other: .block 024
 .word 0
 .block 067-025
 .word 0
 .block 0407-070
 .word 0
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
