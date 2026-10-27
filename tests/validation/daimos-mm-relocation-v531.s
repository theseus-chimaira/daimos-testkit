; Exercising the verbatim production mm_move_extent routine with a controlled
; fit/VM boundary. This is not a real process payload or runqueue test.
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
        setzm vm_calls
        movei 1,1
        movem 1,vm_reject
        setzm result_step
        movei 1,0
        movei 2,02000
        pushj 17,mm_move_extent
        came 1,[-5]             ; stub VM rejection passes back verbatim
        jrst fail1
        move 1,mm_extents
        came 1,[02000,,02000]
        jrst fail1
        move 1,mm_extents+1
        came 1,[01,,07]
        jrst fail1
        move 1,mm_extents+2
        came 1,[02000,,010000]
        jrst fail1
        move 1,mm_extent_count
        caie 1,2
        jrst fail1
        move 1,vm_calls
        caie 1,1
        jrst fail1
        setzm vm_reject
        movei 1,0
        movei 2,02000
        pushj 17,mm_move_extent
        jumpn 1,fail2
        move 1,mm_extents
        came 1,[02000,,06000]
        jrst fail2
        move 1,mm_extents+1
        came 1,[01,,07]
        jrst fail2
        move 1,mm_extents+2
        came 1,[02000,,010000]
        jrst fail2
        move 1,mm_extent_count
        caie 1,2
        jrst fail2
        move 1,vm_calls
        caie 1,2
        jrst fail2
        move 1,pi_balance
        jumpn 1,fail2
        setz 1,
        popj 17,
fail1:  movei 1,1
        popj 17,
fail2:  movei 1,2
        popj 17,

; Contract: missing source descriptor during fit search, restored before VM.
.globl mm_find_fit
mm_find_fit:
        move 5,mm_extent_count
        caie 5,1
        jrst fail_fit
        movei 5,06000
        movem 5,(4)
        movei 1,1
        popj 17,
fail_fit:
        setz 1,
        popj 17,
.globl vm_extent_move
vm_extent_move:
        aos vm_calls
        move 5,mm_extent_count
        caie 5,2
        jrst fail_vm
        move 5,mm_extents
        came 5,[02000,,02000]
        jrst fail_vm
        move 5,mm_extents+1
        came 5,[01,,07]
        jrst fail_vm
        move 5,vm_reject
        jumpn 5,fail_vm
        setz 1,
        popj 17,
fail_vm:
        movni 1,5
        popj 17,
.globl mach_pi_disable
mach_pi_disable:
        aos pi_balance
        movei 1,0123
        popj 17,
.globl mach_pi_restore
mach_pi_restore:
        sos pi_balance
        caie 1,0123
        jrst fail_pi
        setz 1,
        popj 17,
fail_pi:
        movei 1,77
        popj 17,
.bss
.globl mm_extent_count
.globl mm_extent_capacity
.globl mm_extents
mm_extent_count: .block 1
mm_extent_capacity: .block 1
mm_extents: .block 010
vm_calls: .block 1
vm_reject: .block 1
pi_balance: .block 1
result_step: .block 1
.globl __test_exit
__test_exit: .block 1
