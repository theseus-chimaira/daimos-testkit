.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; Check ordinary runnable selection before asserting forced maintenance.
 pushj 17,proc_sched_resched_select
 caie 1,1
 jrst fail_1
 ; A pending reaper may not consume a user quantum before 020 ticks.
 move 1,[0400000,,010]
 movem 1,proc_finish_last_tick_v881
 movei 1,017
 movem 1,proc_timer_clock
 movei 1,4
 movem 1,proc_sched_deferred_ticks
 pushj 17,proc_sched_tick_select
 caie 1,1
 jrst fail_2
 ; Once the throttle expires, a continuously runnable user must
 ; yield one bounded turn to slot 0 even though its run queue is live.
 movei 1,030
 movem 1,proc_timer_clock
 movei 1,4
 movem 1,proc_sched_deferred_ticks
 pushj 17,proc_sched_tick_select
 jumpe 1,check_expired
 jrst fail_3
check_expired:
 skipn proc_sched_deferred_ticks
 jrst check_rt
 jrst fail_4
check_rt:
 ; A real-time owner must never be preempted for this work.
 movei 1,1
 movem 1,proc_rt_owner
 movei 1,4
 movem 1,proc_sched_deferred_ticks
 pushj 17,proc_sched_tick_select
 caie 1,1
 jrst fail_5
 ; Neither may a waiting disk swap be interrupted by maintenance.
 setzm proc_rt_owner
 movei 1,0400
 movem 1,proc_sched_cursor
 movei 1,4
 movem 1,proc_sched_deferred_ticks
 pushj 17,proc_sched_tick_select
 jumpe 1,fail_6
 ; No pending marker: normal runnable process must win.
 setzm proc_finish_last_tick_v881
 setzm proc_sched_cursor
 movei 1,4
 movem 1,proc_sched_deferred_ticks
 pushj 17,proc_sched_tick_select
 caie 1,1
 jrst fail_7
 ; Tick wrap around the 17-bit timestamp must still dispatch idle.
 move 1,[0400000,,0177776]
 movem 1,proc_finish_last_tick_v881
 movei 1,020
 movem 1,proc_timer_clock
 movei 1,4
 movem 1,proc_sched_deferred_ticks
 pushj 17,proc_sched_tick_select
 jumpe 1,check_dormant_rt
 jrst fail_8
check_dormant_rt:
 ; An RT lease on a sleeping process must not starve the reaper
 ; while a different ordinary user remains continuously runnable.
 movei 1,3
 movem 1,proc_high_slot
 movei 1,2
 movem 1,proc_current_slot
 movem 1,proc_runq_head
 move 1,[0300024,,0]
 movem 1,__ptable+5
 movei 1,1
 movem 1,proc_rt_owner
 move 1,[0400000,,010]
 movem 1,proc_finish_last_tick_v881
 movei 1,030
 movem 1,proc_timer_clock
 movei 1,4
 movem 1,proc_sched_deferred_ticks
 pushj 17,proc_sched_tick_select
 jumpe 1,pass
 jrst fail_9
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
done: movem 1,__test_exit
 jrst 4,0
.data
.globl kconst_7_7
kconst_7_7: .word 7,,7
.globl proc_sched_deferred_ticks
proc_sched_deferred_ticks: .word 0
.globl proc_sched_age_phase
proc_sched_age_phase: .word 0
.globl proc_finish_last_tick_v881
proc_finish_last_tick_v881: .word 0
.globl proc_timer_clock
proc_timer_clock: .word 0
.globl proc_current_slot
proc_current_slot: .word 1
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
 .word 04000,,020000
 .word 0200024,,0
 .word __other,,0400000
 .word 04000,,020000
 .word 0200024,,0
__uarea: .block 024
 .word 0
 .block 0410-025
__other: .block 024
 .word 0
 .block 0410-025
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
