.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; A process with no VM or swap record still has a live kernel stack.
 pushj 17,proc_sched_resched_select
 caie 1,1
 jrst fail_1
 move 1,proc_sched_cursor
 caie 1,1
 jrst fail_2
 ; Clearing the owned-cleanup flag excludes this VM-less slot.
 setzm __uarea+024
 setzm proc_sched_cursor
 pushj 17,proc_sched_resched_select
 jumpe 1,check_empty
 jrst fail_3
check_empty:
 ; Restore owned cleanup; its RT lease must not demand disk swap.
 movei 1,04
 movem 1,__uarea+024
 movei 1,1
 movem 1,proc_rt_owner
 setzm proc_sched_cursor
 pushj 17,proc_sched_resched_select
 caie 1,1
 jrst fail_4
 move 1,proc_sched_cursor
 caie 1,1
 jrst fail_5
 ; VM_SPACE_NONE without an owned continuation must not request swap
 ; simply because RT ownership happens to refer to the dead image.
 setzm __uarea+024
 setzm proc_sched_cursor
 pushj 17,proc_sched_resched_select
 jumpe 1,check_invalid_rt
 jrst fail_6
check_invalid_rt:
 skipn proc_sched_cursor
 jrst setup_real_swap
 jrst fail_7
setup_real_swap:
 ; A genuine DISK process uses base zero and owns a swap record.
 setzm __ptable+4
 movei 1,1
 movem 1,__swap_records+1
 setzm proc_sched_cursor
 pushj 17,proc_sched_resched_select
 jumpe 1,check_rt_swap
 jrst fail_7
check_rt_swap:
 move 1,proc_sched_cursor
 trnn 1,0400
 jrst fail_7
 ; Fatal cleanup cannot bypass a concurrent VM transition.
 setom __ptable+4
 movei 1,04
 movem 1,__uarea+024
 movei 1,0200000
 iorm 1,__ptable+3
 setzm proc_rt_owner
 setzm proc_sched_cursor
 pushj 17,proc_sched_resched_select
 jumpe 1,pass
 jrst fail_8
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
done: movem 1,__test_exit
 jrst 4,0
.data
.globl kconst_7_7
kconst_7_7: .word 7,,7
.globl proc_sched_deferred_ticks
proc_sched_deferred_ticks: .word 0
.globl proc_finish_last_tick_v881
proc_finish_last_tick_v881: .word 0
.globl proc_timer_clock
proc_timer_clock: .word 0
.globl proc_sched_age_phase
proc_sched_age_phase: .word 0
.globl proc_current_slot
proc_current_slot: .word 0
.globl proc_rt_owner
proc_rt_owner: .word 0
.globl proc_sched_cursor
proc_sched_cursor: .word 0
.globl proc_runq_head
proc_runq_head: .word 1
.globl proc_swap_pressure_ticks
proc_swap_pressure_ticks: .word 0
.globl proc_swap_records
proc_swap_records: .word __swap_records
__swap_records: .block 2
.globl proc_high_slot
proc_high_slot: .word 2
.globl proc_table
proc_table: .word __ptable
__ptable: .block 3
 .word __uarea,,0400000
 .word -1
 .word 0200024,,0
__uarea: .block 024
 .word 04
 .block 0410-025
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
