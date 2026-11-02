.text
.globl main
main:
 movei 17,__stack+0100
 hrli 17,-0400
 movei 10,2
 movei 11,__descriptor
 movei 1,__extent
 movem 1,(17)
 movei 1,1
 movem 1,__fail_unpin
 movem 1,__fail_free
 movei 1,after_unpin
 movem 1,__resume
 jrst proc_swap_in_read_fail
after_unpin:
 move 1,__unpin_calls
 caie 1,1
 jrst fail
 skipn __free_calls
 jrst check_unpin_transition
 jrst fail
check_unpin_transition:
 move 1,__descriptor
 trnn 1,0200000
 jrst fail
 setzm __fail_unpin
 movei 1,after_free
 movem 1,__resume
 jrst proc_swap_in_read_fail
after_free:
 move 1,__unpin_calls
 caie 1,2
 jrst fail
 move 1,__free_calls
 caie 1,1
 jrst fail
 move 1,__descriptor
 trnn 1,0200000
 jrst fail
 movei 1,after_pin
 movem 1,__resume
 jrst proc_swap_in_pin_fail
after_pin:
 move 1,__free_calls
 caie 1,2
 jrst fail
 move 1,__descriptor
 trnn 1,0200000
 jrst fail
 move 1,__invariant_calls
 caie 1,3
 jrst fail
 setz 1,
 jrst done
fail:
 movei 1,1
done:
 movem 1,__test_exit
 jrst 4,0
.globl mm_unpin
mm_unpin:
 aos __unpin_calls
 move 1,__fail_unpin
 popj 17,
.globl mm_free
mm_free:
 aos __free_calls
 move 1,__fail_free
 popj 17,
.globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
 aos __invariant_calls
 jrst @__resume
.globl proc_swap_in_fail
proc_swap_in_fail:
 movei 1,2
 jrst done
.data
.globl kconst_1_1
kconst_1_1: .word 1,,1
__descriptor: .word 0200000
__resume: .word 0
__fail_unpin: .word 0
__fail_free: .word 0
__unpin_calls: .word 0
__free_calls: .word 0
__invariant_calls: .word 0
__extent: .word 0
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
