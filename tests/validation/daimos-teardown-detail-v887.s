.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; No detailed information for ordinary, invalid or FREE owners.
 movei 2,0401
 pushj 17,proc_control_getteardown_v886
 jumpe 1,check_invalid
 jrst fail_1
check_invalid:
 movei 2,0404
 pushj 17,proc_control_getteardown_v886
 camn 1,[-1]
 jrst check_unknown
 jrst fail_2
check_unknown:
 movei 2,01002
 pushj 17,proc_control_getteardown_v886
 camn 1,[-1]
 jrst file_empty
 jrst fail_3
file_empty:
 ; Fatal FILE owner with no remaining descriptors.
 movei 2,0402
 pushj 17,proc_control_getteardown_v886
 caie 1,010001
 jrst fail_4
 ; Three live descriptors: first is a PIPE on FD 0.
 move 3,[070001,,1]
 movem 3,__u_file+026
 move 3,[020002000010]
 movem 3,__u_file+030
 move 3,[012345,,077]
 movem 3,__u_file+034
 movei 2,0402
 pushj 17,proc_control_getteardown_v886
 caie 1,020015
 jrst fail_5
 ; Successful PIPE close clears only its entry. First now DPY FD 1.
 setzm __u_file+026
 movei 2,0402
 pushj 17,proc_control_getteardown_v886
 caie 1,040411
 jrst fail_6
 ; v886 default status is backwards compatible.
 movei 2,2
 pushj 17,proc_control_getteardown_v886
 caie 1,1
 jrst fail_7
check_mm_pins:
 ; Exact type/owner and 2 physical pins on u-area.
 movei 2,0403
 pushj 17,proc_control_getteardown_v886
 caie 1,012
 jrst fail_8
 ; Detail must not alter the old MM retry query.
 movei 2,3
 pushj 17,proc_control_getteardown_v886
 caie 1,0102
 jrst fail_9
 ; A transient unpin can expose zero pins while reaper is not yet done.
 move 3,[03,,01003]
 movem 3,mm_extents+1
 movei 2,0403
 pushj 17,proc_control_getteardown_v886
 caie 1,2
 jrst fail_10
 ; Wrong type must be distinguishable from a legitimate pin.
 move 3,[01,,01003]
 movem 3,mm_extents+1
 movei 2,0403
 pushj 17,proc_control_getteardown_v886
 caie 1,02006
 jrst fail_11
 ; Exact type with wrong owner.
 move 3,[03,,01004]
 movem 3,mm_extents+1
 movei 2,0403
 pushj 17,proc_control_getteardown_v886
 caie 1,02012
 jrst fail_12
 ; Missing extent is not equivalent to unpinned.
 setzm mm_extent_count
 movei 2,0403
 pushj 17,proc_control_getteardown_v886
 caie 1,02002
 jrst fail_13
pass: setz 1,
 jrst done
fail_1: movei 1,1
 jrst done
fail_2: movei 1,2
 jrst done
fail_3: movei 1,3
 jrst done
fail_4: movei 1,4
 jrst done
fail_5: movei 1,5
 jrst done
fail_6: movei 1,6
 jrst done
fail_7: movei 1,7
 jrst done
fail_8: movei 1,010
 jrst done
fail_9: movei 1,011
 jrst done
fail_10: movei 1,012
 jrst done
fail_11: movei 1,013
 jrst done
fail_12: movei 1,014
 jrst done
fail_13: movei 1,015
done: movem 1,__test_exit
 jrst 4,0
.globl kret_neg1
kret_neg1: seto 1,
 popj 17,
.globl kret_zero
kret_zero: setz 1,
 popj 17,
.globl kret_one
kret_one: movei 1,1
 popj 17,
.data
.globl proc_table
proc_table: .word __ptable
.globl proc_high_slot
proc_high_slot: .word 5
.globl proc_finish_last_tick_v881
proc_finish_last_tick_v881: .word 0400020,,01234
.globl mm_extent_count
mm_extent_count: .word 1
.globl mm_extents
mm_extents:
 .word 0410,,__u_mm
 .word 023,,01003
__ptable:
 .block 3
 .word __u_normal,,0400000
 .word 04000,,020000
 .word 0200000,,0
 .word __u_file,,0400000
 .word 04000,,020000
 .word 0300000,,0
 .word __u_mm,,0600000
 .word -1
 .word 0300000,,0
 .word 0
 .word -1
 .word 0
__u_normal: .block 0410
__u_file: .block 024
 .word 4
 .block 0410-025
__u_mm: .block 067
 .word 0400000,,012345
 .block 0410-070
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
