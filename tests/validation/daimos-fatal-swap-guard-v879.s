.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 move 1,[010000,,0]     ; v925 fixture: saved user return
 movem 1,__uarea+020
 movei 1,4
 movem 1,__uarea+024
 movei 1,1
 pushj 17,proc_swap_out
 camn 1,[-1]
 jrst check_fatal
 jrst fail_1
check_fatal:
 skipn __guard_pass
 jrst check_map
 jrst fail_2
check_map:
 movei 1,2
 movem 1,__uarea+024
 movei 1,1
 pushj 17,proc_swap_out
 camn 1,[-1]
 jrst check_map_blocked
 jrst fail_3
check_map_blocked:
 skipn __guard_pass
 jrst check_no_lock
 jrst fail_4
check_no_lock:
 setzm __uarea+024
 movei 1,1
 pushj 17,proc_swap_out
 jumpe 1,check_unblocked
 jrst fail_5
check_unblocked:
 move 1,__guard_pass
 caie 1,1
 jrst fail_6
 ; An already transitioning slot is excluded even without the tag.
 movei 1,0200000
 iorm 1,__ptable+3
 movei 1,1
 pushj 17,proc_swap_out
 camn 1,[-1]
 jrst check_transition
 jrst fail_7
check_transition:
 move 1,__guard_pass
 caie 1,1
 jrst fail_8
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
done: movem 1,__test_exit
 jrst 4,0
.data
.globl kconst_7_7
kconst_7_7: .word 7,,7
.globl proc_table
proc_table: .word __ptable
__ptable: .block 3
 .word __uarea,,0400000
 .word 04000,,020000
 .word 0200000,,0
__uarea: .block 024
 .word 04
 .block 0410-025
.globl __guard_pass
__guard_pass: .word 0
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
