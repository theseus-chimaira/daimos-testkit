; Source-linked PDP-6 proof of staged MM and backing teardown.
; An accepted physical release must never be repeated after a refused
; backing detach. An MM refusal must retain the original VM owner.
        .text
        .globl main
main:
        setom   fail_mm_v1695
        pushj   17,destroy_v1695
        came    1,[-1]
        jrst    fail1_v1695
        move    1,descriptor_v1695+1
        came    1,[04000,,012000]
        jrst    fail2_v1695
        move    1,mm_owned_v1695
        caie    1,1
        jrst    fail3_v1695
        skipn   detach_calls_v1695
        jrst    retry_mm_v1695
        jrst    fail4_v1695

retry_mm_v1695:
        setzm   fail_mm_v1695
        setom   fail_detach_v1695
        pushj   17,destroy_v1695
        came    1,[-1]
        jrst    fail5_v1695
        move    1,descriptor_v1695+1
        came    1,[-1]                  ; physical VM no longer owned
        jrst    fail6_v1695
        skipn   mm_owned_v1695
        jrst    check_retired_v1695
        jrst    fail7_v1695
check_retired_v1695:
        move    1,mm_calls_v1695
        caie    1,2                    ; refused then successful release
        jrst    fail8_v1695
        move    1,detach_calls_v1695
        caie    1,1
        jrst    fail9_v1695
        move    1,backing_owned_v1695
        caie    1,1                    ; detach refusal retains record
        jrst    fail10_v1695

retry_backing_v1695:
        setzm   fail_detach_v1695
        pushj   17,destroy_v1695
        jumpn   1,fail11_v1695
        move    1,descriptor_v1695+1
        came    1,[-1]
        jrst    fail12_v1695
        move    1,mm_calls_v1695
        caie    1,2                    ; never free physical base twice
        jrst    fail13_v1695
        move    1,detach_calls_v1695
        caie    1,2
        jrst    fail14_v1695
        skipn   backing_owned_v1695
        jrst    pass_v1695
        jrst    fail15_v1695
pass_v1695:
        setz    1,
        popj    17,
fail1_v1695: movei 1,1
        popj 17,
fail2_v1695: movei 1,2
        popj 17,
fail3_v1695: movei 1,3
        popj 17,
fail4_v1695: movei 1,4
        popj 17,
fail5_v1695: movei 1,5
        popj 17,
fail6_v1695: movei 1,6
        popj 17,
fail7_v1695: movei 1,7
        popj 17,
fail8_v1695: movei 1,010
        popj 17,
fail9_v1695: movei 1,011
        popj 17,
fail10_v1695: movei 1,012
        popj 17,
fail11_v1695: movei 1,013
        popj 17,
fail12_v1695: movei 1,014
        popj 17,
fail13_v1695: movei 1,015
        popj 17,
fail14_v1695: movei 1,016
        popj 17,
fail15_v1695: movei 1,017
        popj 17,

destroy_v1695:
        movei   1,descriptor_v1695
        movei   2,2
        pushj   17,vm_space_destroy
        popj    17,

        .globl proc_storage_expect_v30
proc_storage_expect_v30:
        caie    1,2
        jrst    bad_mode_v1695
        jumpe   2,good_mode_v1695
bad_mode_v1695:
        seto    1,
        popj    17,
good_mode_v1695:
        setz    1,
        popj    17,

        .globl fs_provider_reg_call
fs_provider_reg_call:
        seto    1,                     ; unavailable XIP provider
        popj    17,

        .globl mm_free
mm_free:
        aos     mm_calls_v1695
        caie    1,012000
        jrst    bad_mm_v1695
        caie    2,1
        jrst    bad_mm_v1695
        caie    3,2
        jrst    bad_mm_v1695
        skipn   fail_mm_v1695
        jrst    free_mm_v1695
bad_mm_v1695:
        movni   1,5
        popj    17,
free_mm_v1695:
        skipn   mm_owned_v1695
        jrst    bad_mm_v1695
        setzm   mm_owned_v1695
        setz    1,
        popj    17,

        .globl proc_swap_detach
proc_swap_detach:
        caie    1,2
        jrst    bad_mode_v1695
        aos     detach_calls_v1695
        skipn   fail_detach_v1695
        jrst    detach_ok_v1695
        seto    1,
        popj    17,
detach_ok_v1695:
        setzm   backing_owned_v1695
        setz    1,
        popj    17,

        .data
        .globl kconst_2_2
kconst_2_2: .word 2,,2
descriptor_v1695: .word 0
        .word 04000,,012000
        .word 0
mm_owned_v1695: .word 1
backing_owned_v1695: .word 1
fail_mm_v1695: .word 0
fail_detach_v1695: .word 0
mm_calls_v1695: .word 0
detach_calls_v1695: .word 0
        .bss
        .globl __test_exit
__test_exit: .block 1
