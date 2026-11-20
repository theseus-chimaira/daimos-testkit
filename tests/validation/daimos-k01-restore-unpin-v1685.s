; A native isolated restore post-read unpin refusal/continuation test.
        .text
        .globl main
main:
        movei   1,1
        movem   1,k01_refuse
        setzm   k01_free_calls
        setzm   k01_invariant_calls
        movei   1,02000
        push    17,1
        pushj   17,k01_restore_unpin_v1685
        sub     17,[1,,1]
        move    1,k01_invariant_calls
        caie    1,1
        jrst    fail
        skipn   k01_free_calls
        jrst    check_error
        jrst    fail
check_error:
        move    1,k01_error
        came    1,[-4]
        jrst    fail
        movei   1,0
        movem   1,k01_refuse
        setzm   k01_invariant_calls
        movei   1,02000
        push    17,1
        pushj   17,k01_restore_unpin_v1685
        sub     17,[1,,1]
        skipn   k01_invariant_calls
        jrst    check_continue
        jrst    fail
check_continue:
        move    1,k01_continue_calls
        caie    1,1
        jrst    fail
        setz    1,
        popj    17,
fail:   movei   1,1
        popj    17,

        .globl mm_unpin
mm_unpin:
        skipn   k01_refuse
        jrst    unpin_ok
        movni   1,4
        popj    17,
unpin_ok:
        setz    1,
        popj    17,
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        aos     k01_invariant_calls
        movem   1,k01_error
        popj    17,
        .globl proc_swap_in_free_fail
proc_swap_in_free_fail:
        aos     k01_free_calls
        seto    1,
        popj    17,
        .globl k01_restore_continue_v1685
k01_restore_continue_v1685:
        aos     k01_continue_calls
        popj    17,
        .bss
        .globl __test_exit
__test_exit:         .block 1
k01_refuse:         .block 1
k01_free_calls:     .block 1
k01_invariant_calls:.block 1
k01_continue_calls: .block 1
k01_error:          .block 1
