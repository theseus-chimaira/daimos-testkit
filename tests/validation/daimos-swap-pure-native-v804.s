.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 setz 6,
init:
 movei 1,0777
 movem 1,__ram(6)
 aoj 6,
 caige 6,0200
 jrst init
 movei 1,__pure
 pushj 17,proc_swap_exchange_pure_v785
 jumpn 1,fail
 move 1,__zero_calls
 caie 1,1
 jrst fail
 move 1,__reload_calls
 caie 1,1
 jrst fail
 setz 6,
verify:
 move 1,__ram(6)
 move 2,6
 addi 2,01000
 came 1,2
 jrst fail
 aoj 6,
 caige 6,0200
 jrst verify
 setzm __zero_calls
 setzm __reload_calls
 setzm __pure+3
 movei 1,__pure
 pushj 17,proc_swap_exchange_pure_v785
 jumpn 1,fail
 skipn __zero_calls
 jrst verify_no_reload
 jrst fail
verify_no_reload:
 skipn __reload_calls
 jrst pass
 jrst fail
pass: setz 1,
 jrst done
fail: movei 1,1
done: movem 1,__test_exit
 jrst 4,0
.globl fs_zero_words
fs_zero_words:
 aos __zero_calls
 setz 4,
zero_loop:
 setzm 0(1)
 aoj 1,
 aoj 4,
 camge 4,2
 jrst zero_loop
 popj 17,
.globl proc_swap_reload_pure
proc_swap_reload_pure:
 aos __reload_calls
 movei 4,__ram
 came 2,4
 jrst reload_bad
 movei 4,01234
 came 1,4
 jrst reload_bad
 movei 4,__uarea
 came 3,4
 jrst reload_bad
 setz 4,
check_cleared:
 skipn __ram(4)
 jrst cleared_next
 jrst reload_bad
cleared_next:
 aoj 4,
 caige 4,0200
 jrst check_cleared
 setz 4,
reload_loop:
 move 5,4
 addi 5,01000
 movem 5,__ram(4)
 aoj 4,
 caige 4,0200
 jrst reload_loop
 setz 1,
 popj 17,
reload_bad:
 seto 1,
 popj 17,
.globl proc_swap_storage_invariant_v30
proc_swap_storage_invariant_v30:
 halt .
.data
__pure: .word 01234
 .word __ram
 .word __uarea
 .word 0200
__ram: .block 0200
__uarea: .block 1
.bss
.globl __test_exit
__test_exit: .block 1
__zero_calls: .block 1
__reload_calls: .block 1
__stack: .block 0400
