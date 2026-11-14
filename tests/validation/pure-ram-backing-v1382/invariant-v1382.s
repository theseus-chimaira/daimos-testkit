; Native transaction fixture: PI stubs preserve the KCC call ABI.
; The unit test does not claim integration with the hardware PI controller.
        .text
        ; proc_storage_runtime_v30 references the live namespace root.
        ; This isolated PURE/backing test has no VFS mounted namespace.
        .globl vfs_namespace_root
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        halt    .
        .data
vfs_namespace_root: .word 0
        .text
        .globl mach_pi_disable
mach_pi_disable:
        movei   1,0200
        popj    17,
        .globl mach_pi_restore
mach_pi_restore:
        popj    17,
