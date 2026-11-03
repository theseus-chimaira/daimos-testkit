/* Native PDP-6 VFS mount-parent call: AC3 is caller-owned. */
        .text
        .globl main
        .globl vfs_parent_raw_asm
        .globl kret_zero
        .globl kret_neg1
        .globl vfs_namespace_root
        .globl vfs_mount_limit
        .globl vfs_mount_root_base
        .globl vfs_mount_target_base
        .globl __test_exit

main:
        movei 4,mount_roots
        movem 4,vfs_mount_root_base
        movei 4,mount_targets
        movem 4,vfs_mount_target_base
        movei 4,1
        movem 4,vfs_mount_limit
        setzm parent_out

        move 1,[000100,,000123]
        movei 2,parent_out
        movei 3,012345
        pushj 17,vfs_parent
        jumpn 1,fail_return
        move 4,parent_out
        caie 4,0777
        jrst fail_parent
        caie 3,012345
        jrst fail_ac3
        setz 1,
        popj 17,

fail_return:
        movei 1,1
        popj 17,
fail_parent:
        movei 1,2
        popj 17,
fail_ac3:
        movei 1,3
        popj 17,

vfs_parent_raw_asm:
        movem 1,(2)
kret_zero:
        setz 1,
        popj 17,
kret_neg1:
        seto 1,
        popj 17,

        .data
vfs_namespace_root: .word 000777
vfs_mount_limit: .word 0
vfs_mount_root_base: .word 0
vfs_mount_target_base: .word 0
mount_roots: .word 000100000123
mount_targets: .word 0777
        .bss
parent_out: .block 1
__test_exit: .block 1
