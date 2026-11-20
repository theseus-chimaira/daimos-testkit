; Native PDP-6 injection into real MM insertion after relocation.
.text
.globl main
main:
        movei 1,2
        movem 1,mm_extent_count
        movei 1,4
        movem 1,mm_extent_capacity
        move 1,[02000,,02000]
        movem 1,mm_extents
        move 1,[01,,07]
        movem 1,mm_extents+1
        move 1,[02000,,010000]
        movem 1,mm_extents+2
        move 1,[03,,011]
        movem 1,mm_extents+3
        movei 1,INJECT_COUNT_V1690
        movem 1,inject_target_v1690
        setzm inject_calls_v1690
        movei 1,0
        movei 2,02000
        pushj 17,mm_move_extent
        ; A failed publication must never return to the scheduler.
        movei 1,077
        popj 17,
.globl mm_find_fit
mm_find_fit:
        movei 5,06000
        movem 5,(4)
        movei 1,1
        popj 17,
.globl vm_extent_move
vm_extent_move:
        setz 1,
        popj 17,
.globl mach_pi_disable
mach_pi_disable:
        movei 1,0123
        popj 17,
.globl mach_pi_restore
mach_pi_restore:
        setz 1,
        popj 17,
.bss
.globl mm_extent_count
.globl mm_extent_capacity
.globl mm_extents
mm_extent_count: .block 1
mm_extent_capacity: .block 1
mm_extents: .block 010
.globl inject_target_v1690
.globl inject_calls_v1690
inject_target_v1690: .block 1
inject_calls_v1690: .block 1
.globl __test_exit
__test_exit: .block 1
