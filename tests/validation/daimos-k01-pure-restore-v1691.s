; Enter the actual PURE restore path with a live scratch owner.
.text
.globl main
main:
        movei 1,040
        movem 1,backstore_blocks
        movei 1,020
        movem 1,scratch_owner_v1691
        movei 1,0200000
        movem 1,transition_v1691
        movei 14,1
        movei 11,02000
        pushj 17,restore_case_v1691
        ; A failed restore must not return or free scratch.
        movei 1,077
        popj 17,
restore_case_v1691:
        add 17,[011,,011]
        movei 1,020
        movem 1,(17)
        jrst proc_swap_verify_restore_fail
.globl backstore_read
backstore_read:
        seto 1,
        popj 17,
.globl backstore_free
backstore_free:
        aos free_calls_v1691
        setz 1,
        popj 17,
.globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        movei 1,076
        popj 17,
.bss
.globl backstore_blocks
backstore_blocks: .block 1
scratch_owner_v1691: .block 1
transition_v1691: .block 1
free_calls_v1691: .block 1
.globl __test_exit
__test_exit: .block 1
