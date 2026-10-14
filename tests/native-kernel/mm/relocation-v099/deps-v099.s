/* Native relocation contract fixture; real MM assembly remains under test. */
.text
.globl vm_extent_move
.globl proc_swap_reclaim
.globl fs_memory_reclaim
.globl mach_pi_disable
.globl mach_pi_restore
vm_extent_move:
        ; For success, verify the original descriptor was restored before callback.
        move 5,mm_extent_count
        caie 5,2
        jrst move_bad
        hrrz 5,mm_extents
        caie 5,024000
        jrst move_bad
        move 5,1
        movem 5,moved_owner
        move 5,2
        movem 5,moved_source
        move 5,4
        movem 5,moved_dest
        move 5,move_result
        move 1,5
        popj 17,
move_bad:
        movei 1,077
        popj 17,
proc_swap_reclaim:
        seto 1,
        popj 17,
fs_memory_reclaim:
        seto 1,
        popj 17,
mach_pi_disable:
        aos pi_disabled
        movei 1,01234
        popj 17,
mach_pi_restore:
        caie 1,01234
        jrst pi_bad
        aos pi_restored
        setz 1,
        popj 17,
pi_bad:
        movei 1,077
        popj 17,
.bss
.globl move_result
.globl moved_owner
.globl moved_source
.globl moved_dest
.globl pi_disabled
.globl pi_restored
move_result: .block 1
moved_owner: .block 1
moved_source: .block 1
moved_dest: .block 1
pi_disabled: .block 1
pi_restored: .block 1
