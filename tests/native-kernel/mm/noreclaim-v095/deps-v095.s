/* Deliberately isolated callbacks, not allocator replacements. */
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
        seto 1,
        popj 17,
fs_memory_reclaim:
        seto 1,
        popj 17,
mach_pi_disable:
        setz 1,
        popj 17,
mach_pi_restore:
        setz 1,
        popj 17,
