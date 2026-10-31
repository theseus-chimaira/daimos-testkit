.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; Invalid IDs are not a valid diagnostic result.
 setz 2,
 pushj 17,proc_control_getteardown_v886
 camn 1,[-1]
 jrst try_overflow
 jrst fail_1
try_overflow:
 movei 2,5
 pushj 17,proc_control_getteardown_v886
 camn 1,[-1]
 jrst try_free
 jrst fail_2
try_free:
 movei 2,4
 pushj 17,proc_control_getteardown_v886
 camn 1,[-1]
 jrst normal
 jrst fail_3
normal:
 movei 2,1
 pushj 17,proc_control_getteardown_v886
 jumpe 1,try_file
 jrst fail_4
try_file:
 movei 2,2
 pushj 17,proc_control_getteardown_v886
 caie 1,1
 jrst fail_5
 ; Bit 2 isn't meaningful for the fatal FILE owner: no private
 ; stack address, FILE handles, or unsupported timer estimate leaks.
 movei 2,3
 pushj 17,proc_control_getteardown_v886
 caie 1,0102             ; 020 ticks << 2 | stage 2
 jrst fail_6
 ; An MM marker without VM_NONE is not a deferred teardown.
 move 3,[04000,,020000]
 movem 3,__ptable+012
 movei 2,3
 pushj 17,proc_control_getteardown_v886
 jumpe 1,recover_vm_none
 jrst fail_7
recover_vm_none:
 setom __ptable+012
 ; An MM marker without TRANSITION must never be diagnosed as pending.
 move 3,__ptable+011
 and 3,[-0200001]
 movem 3,__ptable+011
 movei 2,3
 pushj 17,proc_control_getteardown_v886
 jumpe 1,recover_transition
 jrst fail_8
recover_transition:
 movei 3,0200000
 iorm 3,__ptable+011
 move 3,[0401000,,01234]
 movem 3,proc_finish_last_tick_v881
 movei 2,3
 pushj 17,proc_control_getteardown_v886
 caie 1,04002            ; 01000 ticks << 2 | stage 2
 jrst fail_9
 ; Zombie with no u-area still returns NONE.
 move 3,[0400000,,0]
 movem 3,__ptable+016
 movei 2,4
 pushj 17,proc_control_getteardown_v886
 jumpe 1,pass
 jrst fail_10
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
 .block 3
 ; slot 1: normal RUN owner, no fatal mark
 .word __u_normal,,0400000
 .word 04000,,020000
 .word 0200000,,0
 ; slot 2: APR fatal FILE owner with preserved private continuation
 .word __u_file,,0400000
 .word 04000,,020000
 .word 0300000,,0
 ; slot 3: deferred post-VM MM free
 .word __u_mm,,0600000
 .word -1
 .word 0300000,,0
 ; slot 4: FREE, then switched to ZOMB by this fixture
 .word 0
 .word -1
 .word 0
__u_normal: .block 0410
__u_file: .block 024
 .word 4
 .block 0410-025
__u_mm: .block 024
 .word 0
 .block 067-025
 .word 0400000,,012345
 .block 0410-070
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
