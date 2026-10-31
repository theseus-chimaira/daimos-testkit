.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; An already transitioning slot must be rejected before HUP begins.
 movei 3,0200000
 iorm 3,__ptable+6
 movei 1,2
 movei 2,0123
 pushj 17,proc_finish_slot
 camn 1,[-1]
 jrst check_existing
 jrst fail_1
check_existing:
 skipn __hup_calls
 jrst check_existing_rt
 jrst fail_2
check_existing_rt:
 move 1,proc_rt_owner
 caie 1,2
 jrst fail_3
 movni 3,0200001
 andb 3,__ptable+6
 ; Failure of session HUP must clear transaction and retain RT lease.
 movei 1,2
 movei 2,0123
 pushj 17,proc_finish_slot
 camn 1,[-1]
 jrst check_hup
 jrst fail_4
check_hup:
 move 1,__hup_calls
 caie 1,1
 jrst fail_5
 skipn __hup_transition
 jrst fail_6
 move 1,__hup_rt_owner
 caie 1,2
 jrst fail_7
 skipn __vm_calls
 jrst check_hup_rollback
 jrst fail_8
check_hup_rollback:
 move 1,__ptable+6
 trne 1,0200000
 jrst fail_9
 move 1,proc_rt_owner
 caie 1,2
 jrst fail_10
 ; VM free failure after successful HUP must preserve RT ownership.
 setzm __fail_hup
 movei 1,1
 movem 1,__fail_vm
 movei 1,2
 movei 2,0123
 pushj 17,proc_finish_slot
 camn 1,[-1]
 jrst check_vm
 jrst fail_11
check_vm:
 move 1,__vm_calls
 caie 1,1
 jrst fail_12
 skipn __vm_transition
 jrst fail_13
 move 1,proc_rt_owner
 caie 1,2
 jrst fail_14
 move 1,__ptable+6
 trne 1,0200000
 jrst fail_15
 ; Successful retry commits to zombie and only then releases RT.
 setzm __fail_vm
 movei 1,2
 movei 2,0123
 pushj 17,proc_finish_slot
 jumpe 1,commit_ok
 jrst fail_16
commit_ok:
 skipn proc_rt_owner
 jrst check_status
 jrst fail_17
check_status:
 move 1,__ptable+010
 hlrz 1,1
 andi 1,0700000
 caie 1,0400000
 jrst fail_18
 move 1,__ptable+6
 hlrz 1,1
 caie 1,0123
 jrst fail_19
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
done: movem 1,__test_exit
 jrst 4,0

.globl proc_session_teardown
proc_session_teardown:
 aos __hup_calls
 move 1,__ptable+6
 trne 1,0200000
 setom __hup_transition
 move 1,proc_rt_owner
 movem 1,__hup_rt_owner
 skipn __fail_hup
 jrst hup_ok
 seto 1,
 popj 17,
hup_ok:
 setz 1,
 popj 17,
.globl vm_space_destroy
vm_space_destroy:
 aos __vm_calls
 move 1,__ptable+6
 trne 1,0200000
 setom __vm_transition
 skipn __fail_vm
 jrst vm_ok
 seto 1,
 popj 17,
vm_ok:
 setz 1,
 popj 17,
.globl proc_tty_release_session
proc_tty_release_session: setz 1,
 popj 17,
.globl proc_uarea_release
proc_uarea_release: setz 1,
 popj 17,
.globl proc_runq_remove
proc_runq_remove: setz 1,
 popj 17,
.globl proc_adopt_children_pdp6
proc_adopt_children_pdp6: setz 1,
 popj 17,
.globl proc_notify_parent
proc_notify_parent: setz 1,
 popj 17,
.globl proc_trim_high
proc_trim_high: setz 1,
 popj 17,
.data
.globl kconst_7_7
kconst_7_7: .word 7,,7
.globl proc_table
proc_table: .word __ptable
.globl proc_rt_owner
proc_rt_owner: .word 2
.globl proc_finish_last_tick_v881
proc_finish_last_tick_v881: .word 0
__ptable:
 .block 6
 .word __uarea,,0400400
 .word 04000,,02000
 .word 0200000,,0
__uarea: .block 0410
__fail_hup: .word 1
__fail_vm: .word 0
__hup_calls: .word 0
__vm_calls: .word 0
__hup_rt_owner: .word 0
__hup_transition: .word 0
__vm_transition: .word 0
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
