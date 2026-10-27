        .text
        .globl native_sys_two_paths
        .globl rename_mapping_probe
rename_mapping_probe:
        pushj   17,native_sys_two_paths
        jumpl   1,rename_mapping_done
        movem   1,mapping_old
        movem   2,mapping_new
        pushj   17,vm_user_mapping_release
        setz    1,
rename_mapping_done:
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
        popj    17,                     ; release must preserve AC1
        .globl kret_neg1
kret_neg1:
        seto    1,
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
        .globl mapping_old
mapping_old: .block 1
        .globl mapping_new
mapping_new: .block 1
