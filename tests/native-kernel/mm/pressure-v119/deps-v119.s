/* Instrument only external reclaim services, not the production MM. */
.text
.globl vm_extent_move
.globl proc_swap_reclaim
.globl fs_memory_reclaim
.globl mach_pi_disable
.globl mach_pi_restore
vm_extent_move:
        seto 1,
        popj 17,
proc_swap_reclaim:
        aos swap_calls
        move 1,3
        movem 1,swap_excluded
        seto 1,
        popj 17,
fs_memory_reclaim:
        aos fs_calls
        seto 1,
        popj 17,
mach_pi_disable:
        setz 1,
        popj 17,
mach_pi_restore:
        setz 1,
        popj 17,
.bss
.globl fs_calls
.globl swap_calls
.globl swap_excluded
fs_calls: .block 1
swap_calls: .block 1
swap_excluded: .block 1
