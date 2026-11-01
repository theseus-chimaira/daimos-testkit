.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; Slot 2: VM rollback is pending without an allocated u-area.
 movei 2,2
 pushj 17,proc_control_getteardown_v886
 caie 1,0103
 jrst fail_1
 ; A detail query must never dereference a missing u-area.
 movei 2,0402
 pushj 17,proc_control_getteardown_v886
 caie 1,0103
 jrst fail_2
 ; Slot 3 has a u-area, but its VM is still owned.
 movei 2,3
 pushj 17,proc_control_getteardown_v886
 caie 1,0103
 jrst fail_3
 ; A normal SIDL slot is not an owner waiting for teardown.
 movei 2,4
 pushj 17,proc_control_getteardown_v886
 jumpe 1,check_transition
 jrst fail_4
check_transition:
 move 3,__ptable+6
 and 3,[-0200001]
 movem 3,__ptable+6
 movei 2,2
 pushj 17,proc_control_getteardown_v886
 jumpe 1,restore_transition
 jrst fail_5
restore_transition:
 movei 3,0200000
 iorm 3,__ptable+6
 ; Even if bit 1 appears in a runnable RH link, it is not SIDL.
 move 3,[0200024,,2]
 movem 3,__ptable+010
 movei 2,2
 pushj 17,proc_control_getteardown_v886
 jumpe 1,check_invalid
 jrst fail_6
check_invalid:
 movei 2,5
 pushj 17,proc_control_getteardown_v886
 camn 1,[-1]
 jrst pass
 jrst fail_7
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
__ptable:
 .block 6
 .word 0,,0200407
 .word 04000,,020000
 .word 0100024,,2
 .word __uarea,,0600407
 .word 04000,,020000
 .word 0100024,,2
 .word 0,,0407
 .word 04000,,020000
 .word 0100024,,0
__uarea: .block 0410
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
