.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; No user VM and no swap record. Fatal-close bit keeps executable
 ; executive cleanup eligible when the timer wakes this process.
 pushj 17,proc_sched_resched_select
 caie 1,2
 jrst fail_1
 move 1,proc_sched_cursor
 caie 1,2
 jrst fail_2
 ; Ordinary VM-less jobs must never run as user processes.
 setzm __uarea+024
 pushj 17,proc_sched_resched_select
 jumpe 1,unflagged_skipped
 jrst fail_3
unflagged_skipped:
 movei 1,4
 movem 1,__uarea+024
 ; An RT owner with only a kernel cleanup continuation also runs.
 movei 1,2
 movem 1,proc_rt_owner
 pushj 17,proc_sched_resched_select
 caie 1,2
 jrst fail_4
 setzm proc_rt_owner
 ; Restoring a VM-less *executive* context must not DATAO APR -1.
 movei 1,2
 movem 1,proc_current_slot
 movei 1,__ptable+6
 movem 1,proc_current_ptr
 movei 2,__uarea
 pushj 17,proc_restore_kernel_tail
 skipn __apr_calls
 jrst check_table
 jrst fail_5
check_table:
 move 1,file_table
 caie 1,__uarea+026
 jrst fail_6
 ; The exemption must not cover an untagged ordinary kernel context.
 setzm __uarea+024
 movei 2,__uarea
 pushj 17,proc_restore_kernel_tail
 move 1,__apr_calls
 caie 1,1
 jrst fail_7
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
done: movem 1,__test_exit
 jrst 4,0

.globl vm_activate_current
vm_activate_current:
 aos __apr_calls
 popj 17,
.globl proc_uarea_slot
proc_uarea_slot:
 movei 1,__uarea
 popj 17,

.data
.globl kconst_7_7
kconst_7_7: .word 7,,7
.globl proc_table
proc_table: .word __ptable
.globl proc_high_slot
proc_high_slot: .word 3
.globl proc_runq_head
proc_runq_head: .word 2
.globl proc_sched_cursor
proc_sched_cursor: .word 0
.globl proc_sched_deferred_ticks
proc_sched_deferred_ticks: .word 0
.globl proc_finish_last_tick_v881
proc_finish_last_tick_v881: .word 0
.globl proc_timer_clock
proc_timer_clock: .word 0
.globl proc_swap_pressure_ticks
proc_swap_pressure_ticks: .word 0
.globl proc_sched_age_phase
proc_sched_age_phase: .word 0
.globl proc_current_slot
proc_current_slot: .word 0
.globl proc_current_ptr
proc_current_ptr: .word 0
.globl proc_rt_owner
proc_rt_owner: .word 0
.globl proc_swap_records
proc_swap_records: .word __records
__records: .block 3
__ptable: .block 6
 .word __uarea,,0400000
 .word 0
 .word 0200000,,0
__uarea: .block 024
 .word 4
 .word 0
 .block 0410-026
.globl file_table
file_table: .word 0
.globl pdp10_pi_level6
pdp10_pi_level6: .word 0
.globl mach_kernel_sp
mach_kernel_sp: .word 0
.globl mach_user_sp
mach_user_sp: .word 0
.globl mach_syscall_save
mach_syscall_save: .word 0
__apr_calls: .word 0
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
