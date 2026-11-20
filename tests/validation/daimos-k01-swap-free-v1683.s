; K01 v1683: production post-write mm_free refusal must retain TRANSITION.
        .text
        .globl main
main:
        ; Wrong owner, exact base: real mm_free returns MM_ERR_INVAL.
        move    1,[01,,02]
        pushj   17,setup
        pushj   17,try_release
        move    1,[01,,02]
        pushj   17,expect_refused
        jumpn   1,fail1
        ; A still-pinned extent is MM_BUSY and must also remain locked.
        move    1,[011,,01]
        pushj   17,setup
        pushj   17,try_release
        move    1,[011,,01]
        pushj   17,expect_refused
        jumpn   1,fail2
        ; Exact unpinned owner may be freed and transaction may proceed.
        move    1,[01,,01]
        pushj   17,setup
        pushj   17,try_release
        skipn   mm_extent_count
        jrst    check_success
        jrst    fail3
check_success:
        skipn   invariant_calls
        jrst    check_done
        jrst    fail3
check_done:
        move    1,success_calls
        caie    1,1
        jrst    fail3
        setz    1,
        popj    17,
fail1:  movei   1,1
        popj    17,
fail2:  movei   1,2
        popj    17,
fail3:  movei   1,3
        popj    17,

setup:
        movem   1,mm_extents+1
        move    2,[02000,,02000]
        movem   2,mm_extents
        movei   2,1
        movem   2,mm_extent_count
        movei   2,0200000
        movem   2,proc_state
        setzm   invariant_calls
        setzm   success_calls
        popj    17,
try_release:
        push    17,010
        push    17,013
        movei   010,1
        movei   013,02000
        pushj   17,proc_swap_free_fragment_v1683
        pop     17,013
        pop     17,010
        popj    17,
expect_refused:
        came    1,mm_extents+1
        jrst    bad
        move    2,mm_extent_count
        caie    2,1
        jrst    bad
        move    2,invariant_calls
        caie    2,1
        jrst    bad
        skipn   success_calls
        jrst    check_transition
        jrst    bad
check_transition:
        move    2,proc_state
        trnn    2,0200000
        jrst    bad
        setz    1,
        popj    17,
bad:    seto    1,
        popj    17,

        .globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
        aos     invariant_calls
        popj    17,
        .globl proc_swap_free_ok_v1683
proc_swap_free_ok_v1683:
        aos     success_calls
        popj    17,
        .globl proc_swap_out_record_fail
proc_swap_out_record_fail:
        ; Unsafe legacy branch clears the transition before returning.
        setzm   proc_state
        popj    17,

        .bss
        .globl __test_exit
        .globl mm_extents
        .globl mm_extent_count
__test_exit:     .block 1
mm_extents:      .block 2
mm_extent_count: .block 1
proc_state:      .block 1
invariant_calls: .block 1
success_calls:   .block 1
