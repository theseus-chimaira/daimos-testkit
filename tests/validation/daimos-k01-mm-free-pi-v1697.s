; Actual MM descriptor release must prove type, owner and pins under PI.
; A simulated interrupt may pin at lock entry or at the delete boundary.
        .text
        .globl main
main:
        ; Incorrect owner is an exact -4 and must not discard the extent.
        pushj   17,setup_v1697
        movei   1,02000
        movei   2,1
        movei   3,2
        pushj   17,mm_free
        came    1,[-4]
        jrst    fail1_v1697
        pushj   17,check_owner_v1697
        jumpn   1,fail2_v1697

        ; An existing physical pin is an exact -5, not freeable.
        pushj   17,setup_v1697
        move    1,[011,,01]
        movem   1,mm_extents+1
        pushj   17,release_v1697
        came    1,[-5]
        jrst    fail3_v1697
        move    1,mm_extents+1
        came    1,[011,,01]
        jrst    fail4_v1697
        pushj   17,check_count_v1697
        jumpn   1,fail5_v1697

        ; Pin acquired just as PI is disabled must be observed before
        ; the code reads the descriptor and checks the pin field.
        pushj   17,setup_v1697
        setom   inject_at_lock_v1697
        pushj   17,release_v1697
        came    1,[-5]
        jrst    fail6_v1697
        move    1,mm_extents+1
        came    1,[011,,01]
        jrst    fail7_v1697
        pushj   17,check_count_v1697
        jumpn   1,fail8_v1697

        ; A pinning interrupt requested immediately before delete may
        ; only run if the PI lock has NOT been held by the releaser.
        pushj   17,setup_v1697
        setom   inject_at_delete_v1697
        pushj   17,release_v1697
        jumpn   1,fail9_v1697
        skipn   mm_extent_count
        jrst    check_no_race_v1697
        jrst    fail10_v1697
check_no_race_v1697:
        skipn   injected_delete_v1697
        jrst    check_pi_v1697
        jrst    fail11_v1697
check_pi_v1697:
        skipn   pi_depth_v1697
        jrst    success_v1697
        jrst    fail12_v1697
success_v1697:
        setz    1,
        popj    17,

release_v1697:
        movei   1,02000
        movei   2,1
        movei   3,1
        pushj   17,mm_free
        popj    17,

setup_v1697:
        movei   1,1
        movem   1,mm_extent_count
        move    1,[02000,,02000]
        movem   1,mm_extents
        move    1,[01,,01]
        movem   1,mm_extents+1
        setzm   inject_at_lock_v1697
        setzm   inject_at_delete_v1697
        setzm   injected_delete_v1697
        setzm   pi_depth_v1697
        popj    17,

check_owner_v1697:
        move    1,mm_extents+1
        came    1,[01,,01]
        jrst    check_bad_v1697
check_count_v1697:
        move    1,mm_extent_count
        caie    1,1
        jrst    check_bad_v1697
        skipn   pi_depth_v1697
        jrst    check_ok_v1697
check_bad_v1697:
        seto    1,
        popj    17,
check_ok_v1697:
        setz    1,
        popj    17,

fail1_v1697: movei 1,1
        popj 17,
fail2_v1697: movei 1,2
        popj 17,
fail3_v1697: movei 1,3
        popj 17,
fail4_v1697: movei 1,4
        popj 17,
fail5_v1697: movei 1,5
        popj 17,
fail6_v1697: movei 1,6
        popj 17,
fail7_v1697: movei 1,7
        popj 17,
fail8_v1697: movei 1,010
        popj 17,
fail9_v1697: movei 1,011
        popj 17,
fail10_v1697: movei 1,012
        popj 17,
fail11_v1697: movei 1,013
        popj 17,
fail12_v1697: movei 1,014
        popj 17,

        .globl mach_pi_disable
mach_pi_disable:
        aos     pi_depth_v1697
        skipn   inject_at_lock_v1697
        jrst    pi_ready_v1697
        setzm   inject_at_lock_v1697
        move    0,[011,,01]
        movem   0,mm_extents+1
pi_ready_v1697:
        movei   1,0200                 ; PI had been enabled
        popj    17,

        .globl mach_pi_restore
mach_pi_restore:
        caie    1,0200
        jrst    pi_error_v1697
        sos     pi_depth_v1697
        popj    17,
pi_error_v1697:
        setom   pi_depth_v1697
        popj    17,

        .bss
        .globl mm_extent_count
        .globl mm_extents
        .globl inject_at_delete_v1697
        .globl injected_delete_v1697
        .globl pi_depth_v1697
        .globl __test_exit
mm_extent_count: .block 1
mm_extents: .block 4
inject_at_lock_v1697: .block 1
inject_at_delete_v1697: .block 1
injected_delete_v1697: .block 1
pi_depth_v1697: .block 1
__test_exit: .block 1
