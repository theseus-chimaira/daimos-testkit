        .text
        .globl rename_full_probe
rename_full_probe:
        pushj   17,native_sys_two_paths
        jumpl   1,rename_full_return
        pushj   17,file_rename
        jrst    vm_user_mapping_release
rename_full_return:
        popj    17,

        .globl vm_user_mapping_hold
vm_user_mapping_hold:
        aos     mapping_holds
        popj    17,
        .globl vm_user_words
vm_user_words:
        aos     mapping_calls
        move    0,mapping_calls
        camn    0,mapping_fail_call
        setz    1,
        popj    17,
        .globl vm_user_mapping_release
vm_user_mapping_release:
        aos     mapping_releases
        popj    17,

        .globl fs_provider_reg_call
fs_provider_reg_call:
        ; Model a provider blocking and waking while the syscall lease is
        ; held. Deliberately overwrite scratch ACs as an event switch can.
        push    17,6
        push    17,1
        pushj   17,rename_simulated_wait_v464
        pop     17,1
        pop     17,6
        move    0,mapping_holds
        came    0,mapping_releases
        jrst    rename_provider_held
        aos     rename_provider_without_hold
rename_provider_held:
        aos     rename_test_calls
        movem   6,rename_test_op
        move    1,rename_test_result
        popj    17,
rename_simulated_wait_v464:
        aos     rename_wait_calls
        move    0,mapping_holds
        camn    0,mapping_releases
        aos     rename_provider_without_hold
        seto    2,
        seto    3,
        seto    4,
        seto    5,
        popj    17,

        .bss
        .globl mapping_holds
mapping_holds: .block 1
        .globl mapping_releases
mapping_releases: .block 1
        .globl mapping_calls
mapping_calls: .block 1
        .globl mapping_fail_call
mapping_fail_call: .block 1
        .globl rename_provider_without_hold
rename_provider_without_hold: .block 1
        .globl rename_wait_calls
rename_wait_calls: .block 1
        .globl rename_test_calls
rename_test_calls: .block 1
        .globl rename_test_op
rename_test_op: .block 1
        .globl rename_test_result
rename_test_result: .block 1
