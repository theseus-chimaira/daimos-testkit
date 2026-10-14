.text
.globl mach_pi_disable
.globl mach_pi_restore
.globl proc_swap_reclaim
.globl fs_memory_reclaim
.globl proc_runq_remove
.globl proc_runq_add
.globl proc_current_slot
.globl proc_table
mach_pi_disable:
        aos pi_disabled
        movei 1,01234
        popj 17,
mach_pi_restore:
        caie 1,01234
        jrst bad_pi
        aos pi_restored
        popj 17,
bad_pi: seto 1,
        popj 17,
proc_swap_reclaim: seto 1,
        popj 17,
fs_memory_reclaim: seto 1,
        popj 17,
proc_runq_remove: aos runq_removed
        popj 17,
proc_runq_add: aos runq_added
        popj 17,
.bss
proc_current_slot: .block 1
proc_table: .block 1
.globl pi_disabled
.globl pi_restored
.globl runq_removed
.globl runq_added
pi_disabled: .block 1
pi_restored: .block 1
runq_removed: .block 1
runq_added: .block 1
