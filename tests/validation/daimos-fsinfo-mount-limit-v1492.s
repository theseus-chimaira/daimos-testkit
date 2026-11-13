; Execute the production FSINFO handler in a PDP-6 test process.
; A capacity request must neither map user memory nor inspect providers.
        .text
        .globl main
        .globl native_sys_fsinfo
        .globl __test_exit
        .globl vfs_mount_limit
        .globl vfs_mount_root_base
        .globl vfs_mount_target_base
        .globl vfs_mount_policy
        .globl vfs_namespace_root
        .globl fs_provider_reg_call
        .globl native_sys_map_one
        .globl file_getpath
        .globl vm_user_mapping_release
        .globl kret_neg1
        .globl kconst_7_7

main:
        movei   1,010                  ; eight decimal mount slots
        movem   1,vfs_mount_limit
        movei   1,mount_roots_v1492
        movem   1,vfs_mount_root_base
        movei   1,mount_targets_v1492
        movem   1,vfs_mount_target_base

        ; Exact all-ones slot is a pointer-free, provider-free query.
        seto    2,
        seto    3                      ; intentionally invalid user pointer
        pushj   17,native_sys_fsinfo
        caie    1,010
        jrst    fail_v1492
        skipn   provider_calls_v1492
        jrst    capacity_ok_v1492
        jrst    fail_v1492
capacity_ok_v1492:
        ; A valid but unoccupied last slot returns zero, not end-of-list.
        movei   2,7
        seto    3
        pushj   17,native_sys_fsinfo
        jumpn   1,fail_v1492

        ; The first invalid slot preserves the established -1 result.
        movei   2,010
        seto    3
        pushj   17,native_sys_fsinfo
        camn    1,[-1]
        jrst    bad_slot_ok_v1492
        jrst    fail_v1492
bad_slot_ok_v1492:
        ; Boundary mount capacities above the historical four-slot limit.
        movei   1,032                  ; 26 decimal slots
        movem   1,vfs_mount_limit
        seto    2,
        setz    3,
        pushj   17,native_sys_fsinfo
        caie    1,032
        jrst    fail_v1492

        ; A zero/unpublished table must fail closed, never claim capacity 0.
        setzm   vfs_mount_limit
        seto    2,
        pushj   17,native_sys_fsinfo
        camn    1,[-1]
        jrst    success_v1492
        jrst    fail_v1492
success_v1492:
        setz    1,
        popj    17,
fail_v1492:
        movei   1,1
        popj    17,

; The normal occupied-slot code is linked unchanged but deliberately never
; invoked; it would need real VFS, MM and user-memory ownership fixtures.
fs_provider_reg_call:
        aos     provider_calls_v1492
        seto    1,
        popj    17,
native_sys_map_one:
        aos     provider_calls_v1492
        setz    1,
        popj    17,
file_getpath:
        aos     provider_calls_v1492
        seto    1,
        popj    17,
vm_user_mapping_release:
        aos     provider_calls_v1492
        setz    1,
        popj    17,
kret_neg1:
        seto    1,
        popj    17,

        .data
kconst_7_7: .word 7,,7

        .bss
vfs_mount_limit:       .block 1
vfs_mount_root_base:   .block 1
vfs_mount_target_base: .block 1
vfs_mount_policy:      .block 1
vfs_namespace_root:    .block 1
mount_roots_v1492:     .block 032
mount_targets_v1492:   .block 032
provider_calls_v1492: .block 1
__test_exit:           .block 1
