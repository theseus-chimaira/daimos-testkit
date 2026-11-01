.text
.globl main
main:
 movei 17,__stack-1
 hrli 17,-0400
 ; Native PIPE node: one 36-bit word per character syscall.
 move 1,[070001,,__pipe]
 setz 2,
 movei 3,0101                 ; 'A'
 pushj 17,vfs_writechar
 jumpe 1,check_queued
 jrst fail_1
check_queued:
 move 1,__pipe+2
 andi 1,0177777
 caie 1,1
 jrst fail_2
 move 1,[070001,,__pipe]
 setz 2,
 movei 3,__ch
 pushj 17,vfs_readchar
 caie 1,1
 jrst fail_3
 move 1,__ch
 caie 1,0101
 jrst fail_4
 move 1,__pipe+2
 andi 1,0177777
 jumpe 1,check_eof
 jrst fail_5
check_eof:
 movsi 1,1
 movem 1,__pipe+3          ; last writer closed, one reader remains
 setom __ch
 move 1,[070001,,__pipe]
 setz 2,
 movei 3,__ch
 pushj 17,vfs_readchar
 jumpe 1,check_eof_untouched
 jrst fail_6
check_eof_untouched:
 move 1,__ch
 camn 1,[-1]
 jrst check_broken
 jrst fail_7
check_broken:
 setz 1,
 movem 1,__pipe+3          ; no readers or writers
 move 1,[070001,,__pipe]
 setz 2,
 movei 3,0102
 pushj 17,vfs_writechar
 camn 1,[-1]
 jrst check_device
 jrst fail_8
check_device:
 move 1,[020002,,__pipe]
 setz 2,
 movei 3,__ch
 pushj 17,vfs_readchar
 caie 1,1
 jrst fail_9
 move 1,__ch
 caie 1,077
 jrst fail_10
 move 1,[020002,,__pipe]
 setz 2,
 movei 3,0101
 pushj 17,vfs_writechar
 camn 1,[-3]
 jrst pass
 jrst fail_11
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
done: movem 1,__test_exit
 jrst 4,0
.globl pipe_wait_event
pipe_wait_event: seto 1,
 popj 17,
.globl pipe_signal_event
pipe_signal_event: setz 1,
 popj 17,
.globl proc_event_apply
proc_event_apply: seto 1,
 popj 17,
.globl proc_current_slot
proc_current_slot: .word 1
.globl mfsdev_readchar
mfsdev_readchar:
 movei 4,077
 movem 4,(3)
 movei 1,1
 popj 17,
.globl kret_zero
kret_zero: setz 1,
 popj 17,
.globl kret_neg1
kret_neg1: seto 1,
 popj 17,
.globl kret_busy
kret_busy: movni 1,3
 popj 17,
.globl kconst_1_1
kconst_1_1: .word 1,,1
.data
__pipe: .word 0
        .word 0
        .word 0
        .word 1,,1
        .block 012
__ch: .word 0
.bss
__stack: .block 0400
.globl __test_exit
__test_exit: .block 1
