; Verify production swap-in MM pin/owner preflight before any image write.
; Invariant refusal must retain TRANSITION and authoritative disk state.
        .equ PROC_TRANSITION_RH,0200000
        .text
        .globl main
main:
        ; A slot-2 PROCESS descriptor must not be used for slot 1.
        move    1,[02000,,02000]
        move    2,[01,,02]
        pushj   17,k01_setup
        pushj   17,k01_try
        move    1,[011,,02]
        pushj   17,k01_expect_refusal
        jumpn   1,k01_fail1

        ; A non-PROCESS extent with the same numerical owner is unsafe.
        move    1,[02000,,02000]
        move    2,[03,,01]
        pushj   17,k01_setup
        pushj   17,k01_try
        move    1,[013,,01]
        pushj   17,k01_expect_refusal
        jumpn   1,k01_fail2

        ; Wrong length would overwrite memory outside the MM grant.
        move    1,[04000,,02000]
        move    2,[01,,01]
        pushj   17,k01_setup
        pushj   17,k01_try
        move    1,[011,,01]
        pushj   17,k01_expect_refusal
        jumpn   1,k01_fail3

        ; A second physical pin cannot be treated as sole ownership.
        move    1,[02000,,02000]
        move    2,[011,,01]
        pushj   17,k01_setup
        pushj   17,k01_try
        move    1,[021,,01]
        pushj   17,k01_expect_refusal
        jumpn   1,k01_fail4

        ; Exact slot, PROCESS type, allocation size and one new pin.
        move    1,[02000,,02000]
        move    2,[01,,01]
        pushj   17,k01_setup
        pushj   17,k01_try
        skipn   k01_invariant_calls
        jrst    k01_valid
        jrst    k01_fail5
k01_valid:
        move    1,k01_verified_calls
        caie    1,1
        jrst    k01_fail5
        move    1,mm_extents+1
        came    1,[011,,01]
        jrst    k01_fail5
        move    1,k01_disk_record
        caie    1,012345
        jrst    k01_fail5
        setz    1,
        popj    17,

k01_fail1: movei 1,1
        popj    17,
k01_fail2: movei 1,2
        popj    17,
k01_fail3: movei 1,3
        popj    17,
k01_fail4: movei 1,4
        popj    17,
k01_fail5: movei 1,5
        popj    17,

k01_setup:
        movem   1,mm_extents
        movem   2,mm_extents+1
        movei   3,1
        movem   3,mm_extent_count
        movei   3,PROC_TRANSITION_RH
        movem   3,k01_proc
        movei   3,012345
        movem   3,k01_disk_record
        setzm   k01_invariant_calls
        setzm   k01_verified_calls
        setzm   k01_pin_fail_calls
        popj    17,

k01_try:
        push    17,010
        push    17,013
        movei   010,1
        movei   013,02000
        movei   1,02000
        push    17,1
k01_enter_fragment:
        ; Real swap-in executes this block within its own stack frame.
        ; A PUSHJ here would put a return PC over the allocated-base local.
        jrst    proc_swap_in_verify_fragment_v1686
k01_resume_fragment:
        sub     17,[1,,1]
        pop     17,013
        pop     17,010
        popj    17,

k01_expect_refusal:
        came    1,mm_extents+1
        jrst    k01_expect_bad
        move    2,mm_extent_count
        caie    2,1
        jrst    k01_expect_bad
        move    2,k01_invariant_calls
        caie    2,1
        jrst    k01_expect_bad
        skipn   k01_verified_calls
        jrst    k01_check_pinfail
        jrst    k01_expect_bad
k01_check_pinfail:
        skipn   k01_pin_fail_calls
        jrst    k01_check_transition
        jrst    k01_expect_bad
k01_check_transition:
        move    2,k01_proc
        trnn    2,PROC_TRANSITION_RH
        jrst    k01_expect_bad
        move    2,k01_disk_record
        caie    2,012345
        jrst    k01_expect_bad
        setz    1,
        popj    17,
k01_expect_bad:
        seto    1,
        popj    17,

        .globl k01_restore_verified_v1686
k01_restore_verified_v1686:
        aos     k01_verified_calls
        jrst    k01_resume_fragment
        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        aos     k01_invariant_calls
        jrst    k01_resume_fragment
        .globl proc_swap_in_pin_fail
proc_swap_in_pin_fail:
        aos     k01_pin_fail_calls
        jrst    k01_resume_fragment

        .bss
        .globl __test_exit
        .globl mm_extents
        .globl mm_extent_count
        .globl k01_proc
        .globl k01_disk_record
        .globl k01_invariant_calls
        .globl k01_verified_calls
        .globl k01_pin_fail_calls
__test_exit:         .block 1
mm_extents:          .block 2
mm_extent_count:     .block 1
k01_proc:            .block 3
k01_disk_record:     .block 1
k01_invariant_calls: .block 1
k01_verified_calls:  .block 1
k01_pin_fail_calls:  .block 1
