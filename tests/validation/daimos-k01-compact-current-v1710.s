; Production PDP-6 MM compaction must skip the executing PROCESS owner.
; The current owner is intentionally immovable. Its normal refusal is
; not proof that a different MM owner is corrupt or unexpectedly pinned.
        .text
        .globl main
main:
        ; Two PROCESS descriptors, slots 1=current, 2=other.
        movei   1,2
        movem   1,mm_extent_count
        move    1,[02000,,02000]
        movem   1,mm_extents
        move    1,[01,,01]
        movem   1,mm_extents+1
        move    1,[02000,,06000]
        movem   1,mm_extents+2
        move    1,[01,,02]
        movem   1,mm_extents+3
        movei   1,1
        movem   1,proc_current_slot

        ; Case 1: only the current VM would refuse; the noncurrent
        ; candidate reports ordinary no-fit. Do not return fake -5.
        movei   1,1
        pushj   17,run_case_v1710
        came    1,[-2]
        jrst    fail1_v1710
        move    1,move_calls_v1710
        caie    1,1
        jrst    fail2_v1710
        move    1,last_slot_v1710
        caie    1,1
        jrst    fail3_v1710

        ; Case 2: a separate owner genuinely refuses relocation.
        ; Preserve -5; do not convert it into ordinary fragmentation.
        movei   1,2
        pushj   17,run_case_v1710
        came    1,[-5]
        jrst    fail4_v1710
        move    1,move_calls_v1710
        caie    1,1
        jrst    fail5_v1710

        ; Case 3: another owner can relocate and enable the fit.
        movei   1,3
        pushj   17,run_case_v1710
        jumpn   1,fail6_v1710
        move    1,move_calls_v1710
        caie    1,1
        jrst    fail7_v1710

        ; Process MM metadata must be unchanged by our mock move.
        move    1,mm_extents+1
        came    1,[01,,01]
        jrst    fail8_v1710
        move    1,mm_extents+3
        came    1,[01,,02]
        jrst    fail9_v1710
        setz    1,
        popj    17,

run_case_v1710:
        movem   1,mode_v1710
        setzm   move_calls_v1710
        setzm   moved_v1710
        setzm   last_slot_v1710
        movei   1,04000
        movei   2,02000
        pushj   17,mm_compact
        popj    17,

        .globl mm_find_fit
mm_find_fit:
        movei   5,05000
        movem   5,(4)
        skipn   moved_v1710
        jrst    no_fit_v1710
        movei   1,1
        popj    17,
no_fit_v1710:
        setz    1,
        popj    17,

        .globl mm_move_extent
mm_move_extent:
        aos     move_calls_v1710
        movem   1,last_slot_v1710
        ; The old implementation erroneously invoked the VM mover for
        ; slot 0, which is the executing PROCESS. Exact -5 then poisoned
        ; the entire compaction despite unrelated owners remaining.
        jumpe   1,real_current_busy_v1710
        move    3,mode_v1710
        caie    3,2
        jrst    normal_candidate_v1710
real_current_busy_v1710:
        movni   1,5
        popj    17,
normal_candidate_v1710:
        caie    3,3
        jrst    regular_no_fit_v1710
        setom   moved_v1710
        setz    1,
        popj    17,
regular_no_fit_v1710:
        movni   1,2
        popj    17,

fail1_v1710: movei 1,1
        popj 17,
fail2_v1710: movei 1,2
        popj 17,
fail3_v1710: movei 1,3
        popj 17,
fail4_v1710: movei 1,4
        popj 17,
fail5_v1710: movei 1,5
        popj 17,
fail6_v1710: movei 1,6
        popj 17,
fail7_v1710: movei 1,7
        popj 17,
fail8_v1710: movei 1,010
        popj 17,
fail9_v1710: movei 1,011
        popj 17,

        .bss
        .globl mm_extents
        .globl mm_extent_count
        .globl proc_current_slot
        .globl __test_exit
mm_extents: .block 4
mm_extent_count: .block 1
proc_current_slot: .block 1
mode_v1710: .block 1
move_calls_v1710: .block 1
last_slot_v1710: .block 1
moved_v1710: .block 1
__test_exit: .block 1
