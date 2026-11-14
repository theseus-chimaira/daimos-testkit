; Native PDP-6 wrapper test with strict simulated MM lease transitions.
; Actual wrapper instructions are linked from production DAIMOS source.
        .text
        .globl main
        .globl __test_exit
        .globl dtfs_intent_owned_arm_v1552
        .globl mm_alloc_aligned_noreclaim
        .globl mm_pin
        .globl mm_unpin
        .globl mm_free
        .globl dtfs_intent_arm_v1551
        .globl dtfs_intent_verify_v1554

main:
        movei   014,case_table_v1552
        movei   015,013                ; eleven cases (octal 013)
case_start_v1552:
        move    1,(014)
        movem   1,mode_v1552
        setzm   alloc_calls_v1552
        setzm   pin_calls_v1552
        setzm   unpin_calls_v1552
        setzm   free_calls_v1552
        setzm   arm_calls_v1552
        setzm   pinned_v1552
        setzm   basep_v1552
        move    1,mode_v1552
        caie    1,7
        jrst    case_begin_v1552
        movei   1,scratch_v1552
        movem   1,basep_v1552
case_begin_v1552:
        movei   1,2
        movei   2,0123
        movei   3,0456
        movei   4,basep_v1552
        move    5,mode_v1552
        caie    5,010                 ; missing caller basep
        jrst    case_call_v1552
        setz    4,
case_call_v1552:
        pushj   17,dtfs_intent_owned_arm_v1552
        came    1,1(014)
        jrst    case_bad_v1552
        move    1,alloc_calls_v1552
        came    1,2(014)
        jrst    case_bad_v1552
        move    1,pin_calls_v1552
        came    1,3(014)
        jrst    case_bad_v1552
        move    1,unpin_calls_v1552
        came    1,4(014)
        jrst    case_bad_v1552
        move    1,free_calls_v1552
        came    1,5(014)
        jrst    case_bad_v1552
        move    1,arm_calls_v1552
        came    1,6(014)
        jrst    case_bad_v1552
        move    1,pinned_v1552
        came    1,7(014)
        jrst    case_bad_v1552
        move    1,basep_v1552
        move    2,010(014)
        jumpe   2,case_expect_zero_v1552
        caie    1,scratch_v1552
        jrst    case_bad_v1552
        jrst    case_next_v1552
case_expect_zero_v1552:
        jumpn   1,case_bad_v1552
case_next_v1552:
        addi    014,011
        sojg   015,case_start_v1552
        setz    1,
        popj    17,
case_bad_v1552:
        move    1,015                ; case index, always nonzero
        popj    17,

; Full MM no-reclaim ABI: AC1..4 and stack preference/basep.
; The fake MM has one exact physical 0200-word extent, and always
; enforces type/owner/alignment rather than accepting arbitrary calls.
mm_alloc_aligned_noreclaim:
        aos     alloc_calls_v1552
        caie    1,0200
        jrst    bad_mm_call_v1552
        caie    2,1
        jrst    bad_mm_call_v1552
        caie    3,3
        jrst    bad_mm_call_v1552
        caie    4,015
        jrst    bad_mm_call_v1552
        move    5,-1(17)            ; high preference (arg5)
        caie    5,1
        jrst    bad_mm_call_v1552
        move    5,-2(17)            ; pointer-to-base (arg6)
        caie    5,basep_v1552
        jrst    bad_mm_call_v1552
        move    6,mode_v1552
        caie    6,2                 ; allocation fails cleanly
        jrst    mm_allocate_v1552
        seto    1,
        popj    17,
mm_allocate_v1552:
        movei   6,scratch_v1552
        movem   6,(5)
        setz    1,
        popj    17,

mm_pin:
        aos     pin_calls_v1552
        caie    1,scratch_v1552
        jrst    bad_mm_call_v1552
        move    5,mode_v1552
        caie    5,3
        jrst    mm_pin_check_four_v1552
        jrst    mm_pin_refused_v1552
mm_pin_check_four_v1552:
        caie    5,4
        jrst    mm_pin_good_v1552
mm_pin_refused_v1552:
        seto    1,
        popj    17,
mm_pin_good_v1552:
        aos     pinned_v1552
        setz    1,
        popj    17,

mm_unpin:
        aos     unpin_calls_v1552
        caie    1,scratch_v1552
        jrst    bad_mm_call_v1552
        move    5,mode_v1552
        caie    5,5                 ; MM refused to drop pin
        jrst    mm_unpin_good_v1552
        movni   1,5
        popj    17,
mm_unpin_good_v1552:
        sos     pinned_v1552
        setz    1,
        popj    17,

mm_free:
        aos     free_calls_v1552
        caie    1,scratch_v1552
        jrst    bad_mm_call_v1552
        caie    2,3
        jrst    bad_mm_call_v1552
        caie    3,015
        jrst    bad_mm_call_v1552
        skipn   pinned_v1552
        jrst    mm_free_unpinned_v1552
        jrst    bad_mm_call_v1552
mm_free_unpinned_v1552:
        move    5,mode_v1552
        caie    5,4                 ; pin failed, free failed too
        jrst    mm_free_check_six_v1552
        jrst    mm_free_refused_v1552
mm_free_check_six_v1552:
        caie    5,6                 ; ordinary final free refused
        jrst    mm_free_good_v1552
mm_free_refused_v1552:
        movni   1,5
        popj    17,
mm_free_good_v1552:
        setz    1,
        popj    17,

; The real v1551 arm is covered separately in native v1551 tests.
; Here it enforces a correct pin across the entire physical I/O call.
dtfs_intent_arm_v1551:
        aos     arm_calls_v1552
        caie    1,2
        jrst    bad_mm_call_v1552
        caie    2,0123
        jrst    bad_mm_call_v1552
        caie    3,0456
        jrst    bad_mm_call_v1552
        caie    4,scratch_v1552
        jrst    bad_mm_call_v1552
        move    5,pinned_v1552
        caie    5,1
        jrst    bad_mm_call_v1552
        move    5,mode_v1552
        caie    5,1                  ; physical arming refused
        jrst    arm_good_v1552
        seto    1,
        popj    17,
arm_good_v1552:
        setz    1,
        popj    17,

; v1552 baseline invokes ARM only. The shared-MM VERIFY operation
; is exercised by the dedicated v1554 acceptance matrix.
dtfs_intent_verify_v1554:
        seto    1,
        popj    17,

bad_mm_call_v1552:
        ; A wrong MM ABI cannot silently appear to succeed.
        movei   1,0777
        popj    17,

        .data
; Nine fields per case: mode / result / alloc / pin / unpin /
; free / arm / still-pinned / caller-retains-base (nonzero).
case_table_v1552:
        .word 0
        .word 0
        .word 1
        .word 1
        .word 1
        .word 1
        .word 1
        .word 0
        .word 0
        .word 1                   ; arm error, clean release
        .word -1
        .word 1
        .word 1
        .word 1
        .word 1
        .word 1
        .word 0
        .word 0
        .word 2                   ; MM allocation refusal
        .word -1
        .word 1
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 3                   ; pin refusal, free OK
        .word -1
        .word 1
        .word 1
        .word 0
        .word 1
        .word 0
        .word 0
        .word 0
        .word 4                   ; pin refusal, free refusal
        .word -1
        .word 1
        .word 1
        .word 0
        .word 1
        .word 0
        .word 0
        .word 1
        .word 5                   ; unpin refusal, retain pinned base
        .word -1
        .word 1
        .word 1
        .word 1
        .word 0
        .word 1
        .word 1
        .word 1
        .word 6                   ; final free refusal, retain base
        .word -1
        .word 1
        .word 1
        .word 1
        .word 1
        .word 1
        .word 0
        .word 1
        .word 7                   ; preexisting owner must not be lost
        .word -1
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 1
        .word 010                 ; absent caller base pointer
        .word -1
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 0
        .word 011                 ; second successful allocation
        .word 0
        .word 1
        .word 1
        .word 1
        .word 1
        .word 1
        .word 0
        .word 0
        .word 012                 ; second complete successful transaction
        .word 0
        .word 1
        .word 1
        .word 1
        .word 1
        .word 1
        .word 0
        .word 0

        .bss
mode_v1552: .block 1
basep_v1552: .block 1
alloc_calls_v1552: .block 1
pin_calls_v1552: .block 1
unpin_calls_v1552: .block 1
free_calls_v1552: .block 1
arm_calls_v1552: .block 1
pinned_v1552: .block 1
scratch_v1552: .block 0200
__test_exit: .block 1
