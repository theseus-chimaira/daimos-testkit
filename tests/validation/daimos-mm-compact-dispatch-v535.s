; The compactor itself is production assembly. Fit and movement are
; controlled interfaces, allowing verification of selection/return paths.
.text
.globl main
main:
        movei 1,3
        movem 1,mm_extent_count
        ; slot 0 module; slot 1 pinned process; slot 2 movable process
        move 1,[02000,,02000]
        movem 1,mm_extents
        move 1,[02,,01]
        movem 1,mm_extents+1
        move 1,[02000,,04000]
        movem 1,mm_extents+2
        move 1,[011,,02]
        movem 1,mm_extents+3
        move 1,[02000,,06000]
        movem 1,mm_extents+4
        move 1,[01,,03]
        movem 1,mm_extents+5
        setzm move_calls
        setzm moved
        ; Invalid zero request must reject without probing gaps.
        setzm fit_calls
        setz 1,
        movei 2,02000
        pushj 17,mm_compact
        came 1,[-4]
        jrst fail1
        move 1,fit_calls
        jumpn 1,fail1
        ; Capacity enough, but never a sufficient gap before moving slot 2.
        movei 1,02000
        movei 2,02000
        pushj 17,mm_compact
        jumpn 1,fail2
        move 1,move_calls
        caie 1,1
        jrst fail2
        move 1,moved_slot
        caie 1,2
        jrst fail2
        move 1,requested_align
        caie 1,02000
        jrst fail2
        setz 1,
        popj 17,
fail1:  movei 1,1
        popj 17,
fail2:  movei 1,2
        popj 17,
.globl mm_find_fit
mm_find_fit:
        aos fit_calls
        movei 5,020000
        movem 5,(4)
        skipn moved
        jrst no_fit
        movei 1,1
        popj 17,
no_fit: setz 1,
        popj 17,
.globl mm_move_extent
mm_move_extent:
        aos move_calls
        movem 1,moved_slot
        movem 2,requested_align
        movei 5,1
        movem 5,moved
        setz 1,
        popj 17,
.bss
.globl mm_extent_count
.globl mm_extents
mm_extent_count: .block 1
mm_extents: .block 010
fit_calls: .block 1
move_calls: .block 1
moved: .block 1
moved_slot: .block 1
requested_align: .block 1
.globl __test_exit
__test_exit: .block 1
