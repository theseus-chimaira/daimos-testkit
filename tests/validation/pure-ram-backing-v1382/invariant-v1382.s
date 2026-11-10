; Native transaction fixture: PI stubs preserve the KCC call ABI.
; The unit test does not claim integration with the hardware PI controller.
        .text
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        halt    .
        .globl mach_pi_disable
mach_pi_disable:
        movei   1,0200
        popj    17,
        .globl mach_pi_restore
mach_pi_restore:
        popj    17,
