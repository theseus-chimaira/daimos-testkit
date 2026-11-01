.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; Last (15th) descriptor must block teardown without side effects.
 movei 1,2
 movei 2,0123
 pushj 17,proc_finish_slot
 camn 1,[-1]
 jrst check_preflight
 jrst fail_1
check_preflight:
 skipn __helper_calls
 jrst check_owner
 jrst fail_2
check_owner:
 move 1,proc_rt_owner
 caie 1,2
 jrst fail_3
 move 1,__ptable+6
 trnn 1,0400000
 jrst fail_4
 ; Even with empty files, missing stable u-area must fail closed.
 setzm __fd15
 move 1,__ptable+6
 trz 1,0400000
 movem 1,__ptable+6
 movei 1,2
 movei 2,0123
 pushj 17,proc_finish_slot
 camn 1,[-1]
 jrst restore_uarea
 jrst fail_5
restore_uarea:
 skipn __helper_calls
 jrst commit_ready
 jrst fail_6
commit_ready:
 move 1,__ptable+6
 tro 1,0400000
 movem 1,__ptable+6
 movei 1,2
 movei 2,0123
 pushj 17,proc_finish_slot
 jumpe 1,check_commit
 jrst fail_7
check_commit:
 move 1,__helper_calls
 caie 1,7
 jrst fail_8
 skipn proc_rt_owner
 jrst check_zombie
 jrst fail_9
check_zombie:
 move 1,__ptable+010
 hlrz 1,1
 andi 1,0700000
 caie 1,0400000
 jrst fail_10
 move 1,__ptable+6
 hlrz 1,1
 caie 1,0123
 jrst fail_11
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
done: movem 1,__test_exit
 jrst 4,0
.globl proc_session_teardown
proc_session_teardown: aos __helper_calls
 setz 1,
 popj 17,
.globl vm_space_destroy
vm_space_destroy: aos __helper_calls
 setz 1,
 popj 17,
.globl proc_tty_release_session
proc_tty_release_session: aos __helper_calls
 setz 1,
 popj 17,
.globl proc_uarea_release
proc_uarea_release: aos __helper_calls
 setz 1,
 popj 17,
.globl proc_runq_remove
proc_runq_remove: aos __helper_calls
 setz 1,
 popj 17,
.globl proc_adopt_children_pdp6
proc_adopt_children_pdp6: aos __helper_calls
 setz 1,
 popj 17,
.globl proc_notify_parent
proc_notify_parent: aos __helper_calls
 setz 1,
 popj 17,
.globl proc_trim_high
proc_trim_high:
 setz 1,
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
__uarea:
 .block 064
__fd15: .word 020002000001
 .block 0410-065
__helper_calls: .word 0
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1

; v924 fixture: a foreign process finalizer, not the running slot.
.globl proc_current_slot
proc_current_slot: .word 0
