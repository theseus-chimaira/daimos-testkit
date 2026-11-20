; K01: a refused MM release of the temporary destructive-EXEC launch
; copy must never return to the caller as if its owner was retired.
        .text
        .globl main
main:
        ; Ordinary release still returns the original EXEC result.
        pushj   17,reset_v1706
        movei   16,012345
        setzm   mm_result_v1706
        push    17,[02000]
        pushj   17,exec_lowmem_free
        sub     17,[1,,1]
        came    1,[012345]
        jrst    fail1_v1706
        move    1,normal_calls_v1706
        caie    1,1
        jrst    fail2_v1706
        skipn   invariant_calls_v1706
        jrst    try_invalid_v1706
        jrst    fail3_v1706

try_invalid_v1706:
        ; Wrong owner or type: exact -4 must reach the invariant stop.
        pushj   17,reset_v1706
        movni   1,4
        movem   1,mm_result_v1706
        movei   16,012345
        push    17,[02000]
        pushj   17,exec_lowmem_free
        sub     17,[1,,1]
        came    1,[-4]
        jrst    fail4_v1706
        skipn   normal_calls_v1706
        jrst    invalid_invariant_v1706
        jrst    fail5_v1706
invalid_invariant_v1706:
        move    1,invariant_calls_v1706
        caie    1,1
        jrst    fail6_v1706
        pushj   17,verify_free_v1706
        jumpn   1,fail7_v1706

        ; A pinned extent must be treated identically, without unpin.
        pushj   17,reset_v1706
        movni   1,5
        movem   1,mm_result_v1706
        movei   16,012345
        push    17,[02000]
        pushj   17,exec_lowmem_free
        sub     17,[1,,1]
        came    1,[-5]
        jrst    fail8_v1706
        skipn   normal_calls_v1706
        jrst    busy_invariant_v1706
        jrst    fail9_v1706
busy_invariant_v1706:
        move    1,invariant_calls_v1706
        caie    1,1
        jrst    fail10_v1706
        pushj   17,verify_free_v1706
        jumpn   1,fail11_v1706
        setz    1,
        popj    17,

reset_v1706:
        setzm   normal_calls_v1706
        setzm   invariant_calls_v1706
        setzm   free_calls_v1706
        popj    17,
verify_free_v1706:
        move    1,free_calls_v1706
        caie    1,1
        jrst    verify_bad_v1706
        skipn   bad_owner_v1706
        jrst    verify_ok_v1706
verify_bad_v1706:
        seto    1,
        popj    17,
verify_ok_v1706:
        setz    1,
        popj    17,

        .globl mm_free
mm_free:
        caie    1,02000
        jrst    wrong_v1706
        caie    2,3
        jrst    wrong_v1706
        caie    3,013
        jrst    wrong_v1706
        aos     free_calls_v1706
        move    1,mm_result_v1706
        popj    17,
wrong_v1706:
        setom   bad_owner_v1706
        movni   1,4
        popj    17,

        .globl exec_lowmem_return
exec_lowmem_return:
        aos     normal_calls_v1706
        popj    17,
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        ; Test-only witness. Production uses HALT at this label.
        aos     invariant_calls_v1706
        popj    17,

fail1_v1706: movei 1,1
        popj 17,
fail2_v1706: movei 1,2
        popj 17,
fail3_v1706: movei 1,3
        popj 17,
fail4_v1706: movei 1,4
        popj 17,
fail5_v1706: movei 1,5
        popj 17,
fail6_v1706: movei 1,6
        popj 17,
fail7_v1706: movei 1,7
        popj 17,
fail8_v1706: movei 1,010
        popj 17,
fail9_v1706: movei 1,011
        popj 17,
fail10_v1706: movei 1,012
        popj 17,
fail11_v1706: movei 1,013
        popj 17,

        .bss
        .globl __test_exit
normal_calls_v1706: .block 1
invariant_calls_v1706: .block 1
free_calls_v1706: .block 1
bad_owner_v1706: .block 1
mm_result_v1706: .block 1
__test_exit: .block 1
